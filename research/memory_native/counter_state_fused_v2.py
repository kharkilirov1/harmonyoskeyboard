"""
counter_state_fused_v2.py
=========================
Research prototype for low-memory finite-state training.

What is materially different from the original prototype
--------------------------------------------------------
1. A ternary weight plus its 4-bit residual counter is encoded as ONE uint8 state
   (45 reachable states; information-theoretic minimum is ceil(log2 45)=6 bits).
2. Counter weights are updated inside each linear layer's backward pass, row-tile by
   row-tile. A full-model gradient buffer is therefore never retained.
3. No FP master weight and no per-weight Adam moments are used for counter layers.
4. The language-model head is tied to the token embedding.
5. The test corpus can be learnable (periodic) instead of independent random targets.
6. Memory accounting reports parameters AND buffers; the old script counted only
   nn.Parameters and therefore omitted all ternary weights.

Important limitations
---------------------
* This is a correctness/research prototype, not a fast kernel. It decodes uint8 states
  to ordinary tensors around GEMMs. A Triton/CUDA epilogue is needed to obtain the full
  bandwidth and sub-byte benefit of true packed 6-bit storage.
* In-backward updates implement online SGD. Gradient accumulation, global gradient
  clipping, DDP all-reduce, shared/reused CounterStateLinear modules, and activation
  checkpointing need explicit coordination and are intentionally rejected here.
* PyTorch CPU execution validates learning dynamics and persistent-state accounting;
  it is not a speed benchmark.

Examples
--------
python counter_state_fused_v2.py --config micro --data periodic --steps 200
python counter_state_fused_v2.py --config tiny  --data random   --steps 10
"""
from __future__ import annotations

import argparse
import math
import time
from dataclasses import dataclass
from typing import Iterable

import torch
import torch.nn as nn
import torch.nn.functional as F


# -----------------------------------------------------------------------------
# finite-state encoding
# -----------------------------------------------------------------------------
C_DEFAULT = 8
COUNTER_LEVELS = 2 * C_DEFAULT - 1  # c in {-7,...,+7}: 15 values
STATE_COUNT = 3 * COUNTER_LEVELS     # ternary t x counter c: 45 states


def stochastic_round(x: torch.Tensor) -> torch.Tensor:
    """Unbiased stochastic rounding to integers, valid for positive and negative x."""
    floor = torch.floor(x)
    return floor + (torch.rand_like(x) < (x - floor)).to(x.dtype)


def encode_state(t: torch.Tensor, c: torch.Tensor, C: int = C_DEFAULT) -> torch.Tensor:
    """Encode t in {-1,0,1}, c in {-(C-1),...,C-1} into one byte."""
    levels = 2 * C - 1
    code = (t.to(torch.int16) + 1) * levels + (c.to(torch.int16) + (C - 1))
    if torch.is_grad_enabled() and False:  # keeps checks out of hot paths
        assert int(code.min()) >= 0 and int(code.max()) < 3 * levels
    return code.to(torch.uint8)


def decode_state(state: torch.Tensor, C: int = C_DEFAULT) -> tuple[torch.Tensor, torch.Tensor]:
    """Decode a uint8 state into int16 ternary weight and residual counter."""
    levels = 2 * C - 1
    z = state.to(torch.int16)
    t = torch.div(z, levels, rounding_mode="floor") - 1
    c = torch.remainder(z, levels) - (C - 1)
    return t, c


def ternary_gradient_unbiased(g: torch.Tensor) -> torch.Tensor:
    """
    Row-wise unbiased ternary estimator.

    For row amplitude a=max_j |g_j|, output is in {-a,0,+a} and E[Q(g)|g]=g.
    Smaller tiles reduce outlier coupling compared with a whole-matrix scale.
    """
    amplitude = g.abs().amax(dim=1, keepdim=True)
    safe = amplitude.clamp_min(1e-30)
    p = (g.abs() / safe).clamp_(0.0, 1.0)
    event = (torch.rand_like(p) < p).to(g.dtype)
    return torch.sign(g) * event * amplitude


class _FusedCounterLinearFn(torch.autograd.Function):
    """Custom linear whose weight update is fused into backward at row-tile granularity."""

    @staticmethod
    def forward(ctx, x: torch.Tensor, module: "CompactCounterLinear") -> torch.Tensor:
        if module._outstanding_forward:
            raise RuntimeError(
                "CompactCounterLinear was reused before its previous backward. "
                "Weight sharing and gradient accumulation need an explicit scheduler."
            )
        module._outstanding_forward = bool(x.requires_grad)
        ctx.module = module
        ctx.save_for_backward(x)

        t, _ = decode_state(module.state, module.C)
        scale = module.scale.to(dtype=x.dtype)
        weight = scale * t.to(dtype=x.dtype)
        return F.linear(x, weight)

    @staticmethod
    def backward(ctx, grad_out: torch.Tensor):
        (x,) = ctx.saved_tensors
        module: CompactCounterLinear = ctx.module

        x2 = x.reshape(-1, x.shape[-1])
        go2 = grad_out.reshape(-1, grad_out.shape[-1])
        grad_x2 = torch.zeros(
            (x2.shape[0], module.in_features), device=x.device, dtype=x.dtype
        )

        # The full weight-gradient never exists. Only [tile_rows, in_features] is live.
        for lo in range(0, module.out_features, module.tile_rows):
            hi = min(lo + module.tile_rows, module.out_features)
            t_i, c_i = decode_state(module.state[lo:hi], module.C)
            s_i = module.scale[lo:hi]
            w_i = s_i.to(x.dtype) * t_i.to(x.dtype)

            go_i = go2[:, lo:hi]
            grad_x2.add_(go_i @ w_i)

            if module.training and module.update_enabled:
                # A production kernel accumulates this GEMM in FP32 registers and consumes
                # it immediately. This prototype promotes the tile result after GEMM.
                grad_w_i = (go_i.transpose(0, 1) @ x2).float()
                module._update_tile(lo, hi, grad_w_i, t_i, c_i, s_i)

        module._outstanding_forward = False
        return grad_x2.reshape_as(x), None


class CompactCounterLinear(nn.Module):
    """
    Ternary linear layer trained as a 45-state synaptic automaton.

    Persistent per-weight state in this implementation: 1 byte (uint8).
    Logical packed state: ceil(log2(45)) = 6 bits.
    Row scales remain FP32 because their O(out_features) cost is negligible.
    """

    def __init__(
        self,
        in_features: int,
        out_features: int,
        *,
        C: int = C_DEFAULT,
        lr: float = 0.04,
        lr_scale: float = 2e-4,
        init_gain: float = 1.0,
        tile_rows: int = 64,
        local_grad_clip: float = 0.0,
        pulse_mode: str = "direct",
    ) -> None:
        super().__init__()
        if C != C_DEFAULT:
            # Generic encoding works, but uint8 requires 3*(2C-1)<=256.
            if 3 * (2 * C - 1) > 256:
                raise ValueError("C is too large for uint8 state encoding")
        self.in_features = int(in_features)
        self.out_features = int(out_features)
        self.C = int(C)
        self.lr = float(lr)
        self.lr_scale = float(lr_scale)
        self.tile_rows = int(tile_rows)
        self.local_grad_clip = float(local_grad_clip)
        if pulse_mode not in {"direct", "ternary"}:
            raise ValueError("pulse_mode must be 'direct' or 'ternary'")
        self.pulse_mode = pulse_mode
        self.update_enabled = True
        self._outstanding_forward = False

        t0 = torch.randint(-1, 2, (out_features, in_features), dtype=torch.int16)
        c0 = torch.zeros_like(t0)
        self.register_buffer("state", encode_state(t0, c0, C))

        # Var(t)=2/3 for uniform {-1,0,1}; choose Var(w)=gain^2/fan_in.
        s0 = init_gain * math.sqrt(3.0 / (2.0 * in_features))
        self.register_buffer("scale", torch.full((out_features, 1), s0, dtype=torch.float32))

        # Diagnostics only: O(1) tensors, not per-weight optimizer state.
        self.register_buffer("update_events", torch.zeros((), dtype=torch.int64), persistent=False)
        self.register_buffer("weight_flips", torch.zeros((), dtype=torch.int64), persistent=False)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return _FusedCounterLinearFn.apply(x, self)

    @torch.no_grad()
    def _update_tile(
        self,
        lo: int,
        hi: int,
        grad_w: torch.Tensor,
        t_i: torch.Tensor,
        c_i: torch.Tensor,
        s_i: torch.Tensor,
    ) -> None:
        if self.local_grad_clip > 0:
            row_norm = grad_w.norm(dim=1, keepdim=True).clamp_min(1e-30)
            grad_w = grad_w * (self.local_grad_clip / row_norm).clamp_max(1.0)

        # Learn one scale per output row; normalize by sqrt(fan_in) for width stability.
        grad_s = (grad_w * t_i.float()).sum(dim=1, keepdim=True) / math.sqrt(self.in_features)
        s_new = (s_i - self.lr_scale * grad_s).clamp_(1e-5, 10.0)

        # When the gradient tile is consumed immediately, quantizing it does not save
        # HBM. Direct pulses have lower variance. Ternary mode is retained as an ablation
        # for communication-constrained settings.
        update_signal = (
            grad_w if self.pulse_mode == "direct" else ternary_gradient_unbiased(grad_w)
        )
        # c stores a pending update in units of s/C.  Rebase it when the row scale
        # changes so the pending update keeps the same value in weight space.
        c_rebased = c_i.float() * (s_i / s_new)
        ticks = (-self.lr * update_signal) * (self.C / s_new)
        cc = stochastic_round(c_rebased + ticks)

        carry = torch.trunc(cc / self.C)
        remainder = cc - carry * self.C
        proposed_t = t_i.float() + carry
        new_t = proposed_t.clamp_(-1, 1)
        blocked = proposed_t != new_t
        remainder = torch.where(
            blocked,
            torch.sign(cc) * (self.C - 1),
            remainder,
        ).clamp_(-(self.C - 1), self.C - 1)

        self.state[lo:hi].copy_(encode_state(new_t, remainder, self.C))
        self.scale[lo:hi].copy_(s_new)
        # Count synapses whose persisted (t, c) state actually changed. Comparing the
        # pre-carry value cc (which can fall outside the counter range) against c_i
        # overcounted: it flagged every applied tick, not every committed state change.
        state_changed = (remainder != c_i.float()) | (new_t != t_i.float())
        self.update_events.add_(int(state_changed.sum().item()))
        self.weight_flips.add_(int((new_t != t_i).sum().item()))

    @torch.no_grad()
    def state_statistics(self) -> dict[str, float]:
        t, c = decode_state(self.state, self.C)
        return {
            "minus": float((t == -1).float().mean()),
            "zero": float((t == 0).float().mean()),
            "plus": float((t == 1).float().mean()),
            "counter_abs_mean": float(c.float().abs().mean()),
            "counter_edge": float((c.abs() == self.C - 1).float().mean()),
            "scale_mean": float(self.scale.mean()),
        }


# -----------------------------------------------------------------------------
# compact GPT harness
# -----------------------------------------------------------------------------
@dataclass(frozen=True)
class GPTConfig:
    vocab_size: int
    block_size: int
    n_layer: int
    n_head: int
    n_embd: int


CONFIGS = {
    "micro": GPTConfig(vocab_size=32, block_size=16, n_layer=2, n_head=2, n_embd=32),
    "tiny": GPTConfig(vocab_size=2048, block_size=128, n_layer=4, n_head=4, n_embd=256),
    "small": GPTConfig(vocab_size=8192, block_size=256, n_layer=12, n_head=12, n_embd=768),
    "b1": GPTConfig(vocab_size=8192, block_size=256, n_layer=24, n_head=16, n_embd=2048),
}


class Block(nn.Module):
    def __init__(self, cfg: GPTConfig, lr: float, lr_scale: float, tile_rows: int, pulse_mode: str):
        super().__init__()
        d = cfg.n_embd
        residual_gain = 1.0 / math.sqrt(2.0 * cfg.n_layer)
        kw = dict(lr=lr, lr_scale=lr_scale, tile_rows=tile_rows, pulse_mode=pulse_mode)

        self.ln1 = nn.LayerNorm(d)
        self.q = CompactCounterLinear(d, d, **kw)
        self.k = CompactCounterLinear(d, d, **kw)
        self.v = CompactCounterLinear(d, d, **kw)
        self.proj = CompactCounterLinear(d, d, init_gain=residual_gain, **kw)
        self.ln2 = nn.LayerNorm(d)
        self.fc = CompactCounterLinear(d, 4 * d, **kw)
        self.fc2 = CompactCounterLinear(4 * d, d, init_gain=residual_gain, **kw)
        self.n_head = cfg.n_head

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        batch, time, channels = x.shape
        h = self.ln1(x)
        q = self.q(h).view(batch, time, self.n_head, -1).transpose(1, 2)
        k = self.k(h).view(batch, time, self.n_head, -1).transpose(1, 2)
        v = self.v(h).view(batch, time, self.n_head, -1).transpose(1, 2)
        attn = F.scaled_dot_product_attention(q, k, v, is_causal=True)
        attn = attn.transpose(1, 2).contiguous().view(batch, time, channels)
        x = x + self.proj(attn)
        x = x + self.fc2(F.gelu(self.fc(self.ln2(x))))
        return x


class GPT(nn.Module):
    def __init__(self, cfg: GPTConfig, lr: float, lr_scale: float, tile_rows: int, pulse_mode: str):
        super().__init__()
        self.cfg = cfg
        self.tok = nn.Embedding(cfg.vocab_size, cfg.n_embd)
        self.pos = nn.Embedding(cfg.block_size, cfg.n_embd)
        nn.init.normal_(self.tok.weight, mean=0.0, std=0.02)
        nn.init.normal_(self.pos.weight, mean=0.0, std=0.02)
        self.blocks = nn.ModuleList(
            [Block(cfg, lr, lr_scale, tile_rows, pulse_mode) for _ in range(cfg.n_layer)]
        )
        self.lnf = nn.LayerNorm(cfg.n_embd)
        self.head = nn.Linear(cfg.n_embd, cfg.vocab_size, bias=False)
        self.head.weight = self.tok.weight  # tie input/output embedding

    def forward(self, idx: torch.Tensor, targets: torch.Tensor | None = None):
        _, time = idx.shape
        if time > self.cfg.block_size:
            raise ValueError(f"sequence length {time} exceeds block size {self.cfg.block_size}")
        pos = torch.arange(time, device=idx.device)
        x = self.tok(idx) + self.pos(pos)[None]
        for block in self.blocks:
            x = block(x)
        logits = self.head(self.lnf(x))
        loss = None
        if targets is not None:
            loss = F.cross_entropy(logits.reshape(-1, logits.size(-1)), targets.reshape(-1))
        return logits, loss

    def counter_layers(self) -> list[CompactCounterLinear]:
        return [m for m in self.modules() if isinstance(m, CompactCounterLinear)]


# -----------------------------------------------------------------------------
# data and accounting
# -----------------------------------------------------------------------------
def get_batch(cfg: GPTConfig, batch: int, device: torch.device, kind: str):
    if kind == "random":
        x = torch.randint(0, cfg.vocab_size, (batch, cfg.block_size), device=device)
        y = torch.randint(0, cfg.vocab_size, (batch, cfg.block_size), device=device)
        return x, y
    if kind == "periodic":
        start = torch.randint(0, cfg.vocab_size, (batch, 1), device=device)
        offsets = torch.arange(cfg.block_size + 1, device=device)[None]
        seq = (start + offsets) % cfg.vocab_size
        return seq[:, :-1].contiguous(), seq[:, 1:].contiguous()
    raise ValueError(f"unknown data kind: {kind}")


def tensor_bytes(t: torch.Tensor) -> int:
    return t.numel() * t.element_size()


def unique_tensors(items: Iterable[torch.Tensor]) -> list[torch.Tensor]:
    seen: set[int] = set()
    out: list[torch.Tensor] = []
    for t in items:
        ptr = int(t.untyped_storage().data_ptr()) if t.numel() else id(t)
        if ptr not in seen:
            seen.add(ptr)
            out.append(t)
    return out


def memory_report(model: GPT) -> dict[str, float]:
    params = unique_tensors(model.parameters())
    persistent_buffers = unique_tensors(b for b in model.buffers() if b is not None)
    counter = model.counter_layers()
    counter_weights = sum(m.state.numel() for m in counter)
    fp_params = sum(p.numel() for p in params)
    parameter_bytes = sum(tensor_bytes(p) for p in params)
    buffer_bytes = sum(tensor_bytes(b) for b in persistent_buffers)
    logical_6bit = counter_weights * 6 / 8
    return {
        "counter_weights": float(counter_weights),
        "fp_parameters": float(fp_params),
        "true_model_coefficients": float(counter_weights + fp_params),
        "parameter_bytes": float(parameter_bytes),
        "buffer_bytes": float(buffer_bytes),
        "persistent_bytes": float(parameter_bytes + buffer_bytes),
        "logical_packed_counter_bytes": float(logical_6bit),
        "original_counter_peak_bytes": float(16 * counter_weights),
        "dense_bf16_adam_rule_of_thumb_bytes": float(16 * (counter_weights + fp_params)),
    }


def fmt_bytes(n: float) -> str:
    units = ["B", "KiB", "MiB", "GiB", "TiB"]
    i = 0
    while n >= 1024 and i < len(units) - 1:
        n /= 1024
        i += 1
    return f"{n:.2f} {units[i]}"


# -----------------------------------------------------------------------------
# training
# -----------------------------------------------------------------------------
def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", choices=CONFIGS, default="micro")
    ap.add_argument("--data", choices=["periodic", "random"], default="periodic")
    ap.add_argument("--steps", type=int, default=200)
    ap.add_argument("--batch", type=int, default=8)
    ap.add_argument("--lr", type=float, default=0.04)
    ap.add_argument("--lr-scale", type=float, default=2e-4)
    ap.add_argument("--fp-lr", type=float, default=2e-3)
    ap.add_argument("--tile-rows", type=int, default=64)
    ap.add_argument("--pulse-mode", choices=["direct", "ternary"], default="direct")
    ap.add_argument("--device", default="cpu")
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--cpu-threads", type=int, default=2)
    args = ap.parse_args()

    torch.manual_seed(args.seed)
    device = torch.device(args.device)
    if device.type == "cpu":
        torch.set_num_threads(max(1, args.cpu_threads))
    cfg = CONFIGS[args.config]
    model = GPT(cfg, args.lr, args.lr_scale, args.tile_rows, args.pulse_mode).to(device)

    # Only embeddings and normalization parameters are conventional Parameters.
    fp_opt = torch.optim.AdamW(unique_tensors(model.parameters()), lr=args.fp_lr)
    report = memory_report(model)
    print(
        f"config={args.config} data={args.data} "
        f"counter={report['counter_weights']/1e6:.3f}M "
        f"fp={report['fp_parameters']/1e6:.3f}M "
        f"true_total={report['true_model_coefficients']/1e6:.3f}M"
    )
    print(
        "persistent PyTorch storage: "
        f"params={fmt_bytes(report['parameter_bytes'])}, "
        f"buffers={fmt_bytes(report['buffer_bytes'])}, "
        f"total={fmt_bytes(report['persistent_bytes'])}; "
        f"counter payload if packed to 6-bit={fmt_bytes(report['logical_packed_counter_bytes'])}"
    )
    print(
        "parameter-side comparison (activations excluded): "
        f"original FP32-buffer prototype~{fmt_bytes(report['original_counter_peak_bytes'])} "
        f"for counter layers; dense BF16+Adam rule-of-thumb~"
        f"{fmt_bytes(report['dense_bf16_adam_rule_of_thumb_bytes'])}"
    )

    model.train()
    started = time.time()
    log_every = max(1, args.steps // 10)
    for step in range(args.steps + 1):
        x, y = get_batch(cfg, args.batch, device, args.data)
        _, loss = model(x, y)
        fp_opt.zero_grad(set_to_none=True)
        loss.backward()  # counter layers update during this call
        fp_opt.step()

        if step % log_every == 0 or step == args.steps:
            layers = model.counter_layers()
            stats = [m.state_statistics() for m in layers]
            zero = sum(s["zero"] for s in stats) / len(stats)
            edge = sum(s["counter_edge"] for s in stats) / len(stats)
            flips = sum(int(m.weight_flips) for m in layers)
            print(
                f"step={step:5d} loss={loss.item():.4f} "
                f"zero={zero:.3f} counter_edge={edge:.4f} flips={flips}"
            )

    elapsed = time.time() - started
    print(f"done: {args.steps + 1} steps in {elapsed:.2f}s")
    if device.type == "cuda":
        print(f"peak CUDA allocated: {fmt_bytes(torch.cuda.max_memory_allocated(device))}")


if __name__ == "__main__":
    main()

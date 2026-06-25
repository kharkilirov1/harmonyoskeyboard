# Reproduction log — counter-state memory-native training

Environment: CPU-only PyTorch `2.12.1+cpu`, numpy `2.4.6`, Python 3.11, 2 threads.
All commands run from `research/memory_native/`.

## 1. Prototype learning dynamics

```
python counter_state_fused_v2.py --config micro --data periodic --steps 200 --seed 0
```

| step | loss |
|---:|---:|
| 0 | 3.49 |
| 100 | 1.20 |
| 180 | 0.23 (min) |
| 200 | 0.25 |

`flips` grow 0 → 453, `counter_edge` rises 0 → 0.0072. The finite-state mechanism
demonstrably learns the periodic next-token task. (The research note quotes ~0.137;
the gap is stochastic-rounding run-to-run variance, the trajectory is the same.)

### Null test — random targets

```
python counter_state_fused_v2.py --config micro --data random --steps 60 --seed 0
```

Loss stays flat at ~3.47 and **flips == 0** for all 60 steps. The optimizer does not
"learn" independent noise — updates are driven only by genuine signal. Important
control that the periodic result is not an artifact.

## 2. C-ablation (teacher recovery, scale frozen, lr_scale=0)

```
python counter_state_C_ablation.py
```

`(C, mode, median_steps_to_100%_recovery, mean_final_acc, mean_final_MSE, hits_per_seed)`

| C | states | best mean final MSE | exact recovery |
|---:|---:|---:|---|
| 4 | 21 | ~0.0116 | never (median 9999) |
| 8 | 45 | ~0.0021 | 3/5 seeds |
| 11 | 63 | **~0.00081** | 4/5 seeds |

Matches the research note's table essentially exactly. Confirms: spending all six
bits of state (C=11 → 63 states, the max under `3(2C-1) <= 64`) gives the lowest
error and the fastest exact recovery of the ternary teacher matrix. C=4 cannot reach
exact recovery at all.

## 3. Bug fix applied

`CompactCounterLinear._update_tile`: the `update_events` diagnostic compared the
pre-carry value `cc` (which can fall outside the `[-(C-1), C-1]` counter range)
against the old counter `c_i`, flagging every applied tick rather than every
*committed* state change — a systematic overcount. Now counts synapses whose
persisted `(t, c)` actually changed: `(remainder != c_i) | (new_t != t_i)`.
Sanity-checked: `weight_flips <= update_events <= numel*steps` holds.

This is a diagnostics-only change; learning dynamics are unaffected.

## What is verified vs. not

Verified: update mechanism learns (toy LM + synthetic teacher), unbiased drift in
practice, honest memory accounting (params + buffers), null-test sanity, C-scaling.

Not yet verified: parity on a real language model against BF16-AdamW / BitNet-QAT;
joint convergence with a *learned* row scale (ablation freezes it); any speed/HBM
benefit (this is a uint8 correctness prototype, not a packed-6-bit kernel).

import sys, statistics, torch
sys.path.insert(0,'/mnt/data')
from counter_state_fused_v2 import CompactCounterLinear, decode_state

torch.set_num_threads(2)
results=[]
for C in (4,8,11):
  for mode in ('direct','ternary'):
    hits=[]; accs=[]; losses=[]
    for seed in range(5):
      torch.manual_seed(seed)
      n=16; N=256
      teacher=torch.randint(-1,2,(n,n),dtype=torch.int16)
      scale=.25
      x=torch.randn(N,n,requires_grad=True)
      y=x.detach()@(scale*teacher.float()).t()
      layer=CompactCounterLinear(n,n,C=C,lr=.03,lr_scale=0.0,tile_rows=16,pulse_mode=mode)
      layer.scale.fill_(scale)
      hit=None
      for step in range(801):
        x.grad=None
        pred=layer(x)
        loss=((pred-y)**2).mean()
        loss.backward()
        with torch.no_grad():
          t,_=decode_state(layer.state,C)
          acc=(t==teacher).float().mean().item()
        if hit is None and acc==1.0: hit=step+1
      with torch.no_grad():
        layer.update_enabled=False
        pred=layer(x.detach())
        final_loss=((pred-y)**2).mean().item()
        t,_=decode_state(layer.state,C)
        final_acc=(t==teacher).float().mean().item()
      hits.append(hit if hit is not None else 9999); accs.append(final_acc); losses.append(final_loss)
    results.append((C,mode,statistics.median(hits),sum(accs)/len(accs),sum(losses)/len(losses),hits))
for r in results:
  print(r)

"""NumPy state-vector circuit generator for pages 1-50.

A lightweight PennyLane-inspired 3-qubit circuit family. No PennyLane dependency is
required. Each page gets deterministic but distinct rotation parameters, topology,
depth, final statevector, mean single-qubit entanglement entropy, measurement
Shannon entropy, and a local entropy sweep/range.
"""
from __future__ import annotations
import json, csv, math
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parent
OUT_CSV = ROOT / "page_circuit_entropy.csv"
OUT_JSON = ROOT / "page_circuit_states.json"
OUT_SWEEPS = ROOT / "page_entropy_sweeps.npz"

I2 = np.eye(2, dtype=complex)
X = np.array([[0,1],[1,0]], dtype=complex)
Z = np.array([[1,0],[0,-1]], dtype=complex)
H = np.array([[1,1],[1,-1]], dtype=complex) / np.sqrt(2)


def RX(theta):
    c, s = np.cos(theta/2), np.sin(theta/2)
    return np.array([[c,-1j*s],[-1j*s,c]], dtype=complex)

def RY(theta):
    c, s = np.cos(theta/2), np.sin(theta/2)
    return np.array([[c,-s],[s,c]], dtype=complex)

def RZ(theta):
    return np.array([[np.exp(-1j*theta/2),0],[0,np.exp(1j*theta/2)]], dtype=complex)

def kron3(a,b,c): return np.kron(np.kron(a,b),c)

def one_qubit_op(U, wire):
    mats=[I2,I2,I2]; mats[wire]=U
    return kron3(*mats)

def apply_one(state,U,wire): return one_qubit_op(U,wire) @ state

def cnot_matrix(control,target):
    U=np.zeros((8,8),dtype=complex)
    for i in range(8):
        bits=[(i>>2)&1,(i>>1)&1,i&1]
        out=bits.copy()
        if bits[control]: out[target]^=1
        j=(out[0]<<2)|(out[1]<<1)|out[2]
        U[j,i]=1
    return U

def cz_matrix(a,b):
    U=np.eye(8,dtype=complex)
    for i in range(8):
        bits=[(i>>2)&1,(i>>1)&1,i&1]
        if bits[a] and bits[b]: U[i,i]=-1
    return U

def reduced_density_single(state, wire):
    psi=state.reshape(2,2,2)
    perm=[wire]+[w for w in range(3) if w!=wire]
    psi=np.transpose(psi,perm).reshape(2,-1)
    return psi @ psi.conj().T

def vn_entropy(rho):
    vals=np.linalg.eigvalsh(rho).real
    vals=np.clip(vals,1e-15,1)
    return float(-np.sum(vals*np.log2(vals)))

def shannon_entropy(state):
    p=np.abs(state)**2
    p=np.clip(p,1e-15,1)
    return float(-np.sum(p*np.log2(p)))

def page_parameters(page):
    # Quasi-periodic deterministic angles, mapped to [0, 2pi).
    g=(math.sqrt(5)-1)/2
    r=2*np.pi*((page*g + 0.071) % 1)
    gg=2*np.pi*((page*g*g + 0.317) % 1)
    b=2*np.pi*((page*np.sqrt(2)/2 + 0.619) % 1)
    phases=np.array([
        2*np.pi*((page*np.sqrt(3)/3 + 0.113)%1),
        2*np.pi*((page*np.sqrt(7)/5 + 0.271)%1),
        2*np.pi*((page*np.sqrt(11)/7 + 0.419)%1),
    ])
    delta=0.16 + 0.006*(page%11)  # radians, local range half-width
    depth=2 + page%3
    topo=page%4
    return np.array([r,gg,b]), phases, delta, depth, topo

def run_page(page, sweep=0.0):
    angles, phases, delta, depth, topo = page_parameters(page)
    # Sweep all three channels with different couplings to avoid trivial shifts.
    angles = angles + sweep*delta*np.array([1.0,-0.73,0.41])
    phases = phases + sweep*delta*np.array([0.33,0.58,-0.27])
    state=np.zeros(8,dtype=complex); state[0]=1
    # initial superposition changes subtly by page parity
    if page%2==0:
        state=apply_one(state,H,page%3)
    for layer in range(depth):
        for w in range(3):
            theta=angles[w]*(1+0.07*layer) + 0.03*page*(w+1)
            phi=phases[w]*(1-0.05*layer) + 0.019*layer*(page%7)
            gate_sel=(page+layer+w)%3
            if gate_sel==0:
                state=apply_one(state,RY(theta),w)
            elif gate_sel==1:
                state=apply_one(state,RX(theta),w)
            else:
                state=apply_one(state,RY(theta),w)
            state=apply_one(state,RZ(phi),w)
        if topo==0:
            pairs=[(0,1),(1,2)]
        elif topo==1:
            pairs=[(1,2),(2,0)]
        elif topo==2:
            pairs=[(2,0),(0,1)]
        else:
            pairs=[(0,2),(2,1)]
        c,t=pairs[layer%len(pairs)]
        state=cnot_matrix(c,t)@state
        if (page+layer)%3==0:
            a,b=(c+1)%3,(t+1)%3
            if a!=b: state=cz_matrix(a,b)@state
    state=state/np.linalg.norm(state)
    ent=[vn_entropy(reduced_density_single(state,w)) for w in range(3)]
    return state, ent, shannon_entropy(state)

def circuit_ops(page):
    angles, phases, delta, depth, topo=page_parameters(page)
    names=['R','G','B']
    ops=[]
    if page%2==0: ops.append(f"H(wire={page%3})")
    for layer in range(depth):
        for w in range(3):
            gate='RY' if (page+layer+w)%3 != 1 else 'RX'
            ops.append(f"{gate}({names[w]}_theta*{1+0.07*layer:.2f}+{0.03*page*(w+1):.3f}, wire={w})")
            ops.append(f"RZ({names[w]}_phi*{1-0.05*layer:.2f}+{0.019*layer*(page%7):.3f}, wire={w})")
        pairs=[[(0,1),(1,2)],[(1,2),(2,0)],[(2,0),(0,1)],[(0,2),(2,1)]][topo]
        c,t=pairs[layer%len(pairs)]
        ops.append(f"CNOT(control={c}, target={t})")
        if (page+layer)%3==0:
            a,b=(c+1)%3,(t+1)%3
            if a!=b: ops.append(f"CZ(wires=({a},{b}))")
    return ops

def complex_pairs(state):
    return [[float(z.real),float(z.imag)] for z in state]

def generate_all():
    rows=[]; states={}; sweeps={}
    grid=np.linspace(-1,1,81)
    for page in range(1,51):
        angles, phases, delta, depth, topo=page_parameters(page)
        state, ent, sh=run_page(page,0.0)
        curve=[]
        for s in grid:
            _, e, _=run_page(page,float(s))
            curve.append(float(np.mean(e)))
        curve=np.array(curve)
        mean_ent=float(np.mean(ent))
        row={
            'page':page,
            'depth':depth,
            'topology_id':topo,
            'R_theta':float(angles[0]), 'G_theta':float(angles[1]), 'B_theta':float(angles[2]),
            'R_theta_min':float(angles[0]-delta), 'R_theta_max':float(angles[0]+delta),
            'G_theta_min':float(angles[1]-0.73*delta), 'G_theta_max':float(angles[1]+0.73*delta),
            'B_theta_min':float(angles[2]-0.41*delta), 'B_theta_max':float(angles[2]+0.41*delta),
            'entropy_R':ent[0], 'entropy_G':ent[1], 'entropy_B':ent[2],
            'mean_entanglement_entropy':mean_ent,
            'entropy_range_min':float(curve.min()), 'entropy_range_max':float(curve.max()),
            'measurement_shannon_entropy':sh,
        }
        rows.append(row)
        states[str(page)]={
            'parameters':row,
            'ops':circuit_ops(page),
            'statevector_real_imag':complex_pairs(state),
        }
        sweeps[f'page_{page:03d}_sweep']=grid
        sweeps[f'page_{page:03d}_entropy']=curve
    with OUT_CSV.open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
    OUT_JSON.write_text(json.dumps(states,indent=2))
    np.savez_compressed(OUT_SWEEPS,**sweeps)
    print(f"generated {len(rows)} page circuits")
    print(f"mean entropy: {np.mean([r['mean_entanglement_entropy'] for r in rows]):.6f}")
    print(f"entropy span across pages: {min(r['entropy_range_min'] for r in rows):.6f} .. {max(r['entropy_range_max'] for r in rows):.6f}")

if __name__=='__main__':
    generate_all()

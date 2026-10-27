"""Independent SciPy integration of the actual forced differential equation.
No MATLAB propagation routine or formula for its particular solution is reused.
Synthetic numerical case; verification, not physical validation.
"""
import csv
import json
import platform
from pathlib import Path
import numpy as np
import scipy
from scipy.integrate import solve_ivp

ROOT = Path(__file__).resolve().parents[1]


def integrate_segment(state, duration, jerk, w, z):
    # State: command position, velocity, acceleration; relative q, qdot.
    if duration <= 1e-15:
        return state, np.asarray(state)[:, None]
    def rhs(t, y):
        return [y[1], y[2], jerk, y[4], -2*z*w*y[4]-w*w*y[3]-y[2]]
    sol = solve_ivp(rhs, [0, duration], state, method='DOP853',
                    rtol=2e-11, atol=[1e-13, 1e-12, 1e-12, 1e-14, 1e-11],
                    max_step=min(duration, 2*np.pi/(12*w)), dense_output=True)
    assert sol.success, sol.message
    times = np.linspace(0, duration, max(5, int(duration*w/2/np.pi*32)+2))
    return sol.y[:, -1], sol.sol(times)


def main():
    p = json.loads((ROOT/'config.json').read_text(encoding='utf-8'))
    cases = list(csv.DictReader((ROOT/'verification_v02/ode_cases.csv').open(encoding='utf-8-sig')))
    records = []
    for row in cases:
        c = {k: float(v) for k,v in row.items()}
        T,r,u,w,m,k = (c[x] for x in ['T','r','u','w','m','k'])
        z = p['damping_ratio']; h=r*T; tj=u*h
        dt=[tj,h-2*tj,tj,T-2*h,tj,h-2*tj,tj]
        J=p['stroke_m']/(tj*(h-tj)*(T-h))
        js=np.array([1,0,-1,0,-1,0,1])*J
        state=np.array([0.,0.,0.,c['q0'],c['v0']]); samples=[]
        for t,j in zip(dt,js):
            state,y=integrate_segment(state,t,j,w,z); samples.append(y)
        end_up=state.copy()
        wd=w*np.sqrt(1-z*z)
        R=np.hypot(state[3],(state[4]+z*w*state[3])/wd)
        state,y=integrate_segment(state,p['dwell_s'],0.,w,z); samples.append(y)
        for t,j in zip(dt,-js):
            state,y=integrate_segment(state,t,j,w,z); samples.append(y)
        state,y=integrate_segment(state,p['dwell_s'],0.,w,z); samples.append(y)
        ys=np.hstack(samples)
        dyn=np.abs(k*ys[3]+2*z*w*m*ys[4])
        deflection=m*p['gravity_m_s2']/k+np.abs(ys[3])
        rec={'catalog_row':int(c['catalog_row']), 'scenario':int(c['scenario']),
             'q_endpoint_abs_error_m':abs(end_up[3]-c['qT']),
             'v_endpoint_abs_error_m_s':abs(end_up[4]-c['vT']),
             'R_abs_error_m':abs(R-c['R_m']),
             'periodic_q_abs_error_m':abs(state[3]-c['q0']),
             'periodic_v_abs_error_m_s':abs(state[4]-c['v0']),
             'stroke_abs_error_m':abs(end_up[0]-p['stroke_m']),
             'terminal_speed_abs_m_s':abs(end_up[1]),
             'terminal_accel_abs_m_s2':abs(end_up[2]),
             'force_bound_excess_N':max(0.,float(dyn.max()-c['dynamic_force_bound'])),
             'deflection_bound_excess_m':max(0.,float(deflection.max()-c['total_deflection_bound']))}
        assert rec['q_endpoint_abs_error_m'] < 2e-10, rec
        assert rec['v_endpoint_abs_error_m_s'] < 2e-7, rec
        assert rec['R_abs_error_m'] < 2e-10, rec
        assert rec['periodic_q_abs_error_m'] < 2e-10, rec
        assert rec['periodic_v_abs_error_m_s'] < 2e-7, rec
        assert rec['stroke_abs_error_m'] < 1e-10, rec
        assert rec['terminal_speed_abs_m_s'] < 1e-10, rec
        assert rec['terminal_accel_abs_m_s2'] < 1e-10, rec
        assert rec['force_bound_excess_N'] < 1e-5, rec
        assert rec['deflection_bound_excess_m'] < 1e-10, rec
        records.append(rec)
    metrics={key:max(r[key] for r in records) for key in records[0] if key not in ['catalog_row','scenario']}
    result={'status':'PASS','evidence_level':'independent numerical verification, not physical validation',
            'cases':len(records),'maximum_errors':metrics,'python':platform.python_version(),
            'numpy':np.__version__,'scipy':scipy.__version__,'records':records}
    (ROOT/'verification_v02/independent_ode_report.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k!='records'},ensure_ascii=False,indent=2))

if __name__=='__main__':
    main()

import bootstrap
import json,unittest,numpy as np
from run_model import regime_masks
class ExportContract(unittest.TestCase):
    def test_reversal_events_json(self):
        v=np.array([-1.,-.5,0,.5,1.])[:,None]
        _,_,events=regime_masks(v,np.array([.1]),dict(reversal_max_gap_samples=10,reversal_half_window_samples=1,dt=.004))
        self.assertEqual(len(events),1)
        self.assertEqual(json.loads(json.dumps(events))[0]['index'],2)
if __name__=='__main__':unittest.main(verbosity=2)

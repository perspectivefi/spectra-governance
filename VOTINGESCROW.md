# VotingEscrow

To participate in Spectra DAO governance, it is necessary for an account to maintain a certain balance of Vote-escrowed APW (veAPW), which is based on Curve's Vote-Escrowed CRV (veCRV). The veAPW serves as a vault where users can lock their APW for various durations in order to gain voting power.

## State Transitions

This table has functions along the rows, with the state required to call the function. Side effects and the output of the function are listed in the boxes. An empty box means that that state cannot be used as an input into that function.

- Locks can be created with zero amount.
- Increases amount refers to `LockedBalance.amount` being increased. 
- Extends locktime refers to `LockedBalance.end` being extended.

| Function | No lock | Current lock | Expired lock
| --- | --- | --- | --- |
| `create_lock` | - Creates lock. | | |
| `deposit_for` | | - Increases amount. | |
| `increase_amount` | | - Increases amount. | |
| `increase_unlock_time` | | - Extends locktime. | |
| `withdraw` | | | - Withdraw all. |

Find more information on veAPW [here](https://docs.apwine.fi/governance/veapw) and on Curve's `VotingEscrow` contract implementation [here](https://curve.readthedocs.io/dao-vecrv.html)
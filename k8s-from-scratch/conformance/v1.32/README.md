# Conformance tests for GPM Kubernetes from scratch

Creating the cluster will follow the documentation on [ ../../docs/README.md](../../docs/README.md).

This testing is intended to check if the newly-created kubernetes cluster from scratch.
Conformance testing procedures are documented below:
- Download sonobuoy and start the testing
```
sonobuoy run --mode=certified-conformance
```
- Check for results
```
sonobuoy status

        PLUGIN     STATUS   RESULT   COUNT                                PROGRESS
            e2e   complete   passed       1   Passed:  0, Failed:  0, Remaining:411
   systemd-logs   complete   passed       5                                        

Sonobuoy has completed. Use `sonobuoy retrieve` to get results.
```
- Get current sonobuoy test result
```
 sonobuoy retrieve
```
- Collect the results
```
rm -rf results
mkdir results
outfile=$(sonobuoy retrieve)
tar xvzf $outfile -C results
cat results/plugins/e2e/results/global/e2e.log
```
- Cleanup sonobuoy tests
```
./sonobuoy delete
```

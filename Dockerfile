FROM pasientskyhosting/ps-worker
MAINTAINER Andreas Krüger <ak@patientsky.com>

CMD exec /bin/bash -c "trap : TERM INT; sleep infinity & wait"

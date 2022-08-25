# To use docker, you must use dgx queue
# Try interactive first
qsub -I -P 12001458 -q dgx -l walltime=04:00:00 -l select=1:ncpus=15:mem=256gb:ngpus=1

# Then run docker image
nscc-docker run -t <image> # If exit freezed, use ctrl q

# After the routine is stable, you can run with pbs script
qsub <pbs-script>

# Example PBS script
#---------------------------------------
#!/bin/sh

#PBS -N kcy_sgh_main
#PBS -P 12001458
#PBS -q dgx
#PBS -j oe
#PBS -l walltime=24:00:00
#PBS -l select=1:ngpus=1:mem=256gb:ncpus=15
#PBS -k o
#PBS -o ./log

## Loading modules
nscc-docker run nvcr.io/nvidia/kaldi:20.03-py3 > stdout.$PBS_JOBID 2> stderr.$PBS_JOBID << EOF
cd $PBS_O_WORKDIR; 
./run_adapt.sh conf/run_adapt_sgh_150h.conf; 
exit;
EOF
#---------------------------------------
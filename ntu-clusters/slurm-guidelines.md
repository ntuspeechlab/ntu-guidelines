# JOB SUBMISSION USING SLURM
*Yizhou Peng, Nga Ho* 

*MICL@NTU, 22 Jun 2022*

---
## SRUN COMMAND
**srun** is recommended to use for short-running jobs.
## SBATCH COMMAND
**sbatch** is recommended for submitting multiple jobs or a job that is for later execution. 
The script will typically contain one or more srun commands to launch parallel tasks.

### <font color="#4b8bf4">***sbatch** scripts submit example.*</font><br/>
```
#!/bin/bash

steps=1-4
log=$something.log
cmd="slurm.pl --quiet"
nodelist=node01 # nodelist should always be one node only
# if you want to submit your jobs to one of multiple nodes
exclude=node0[2,4,6]

sbatch -o $log -w $nodelist $something.sh --steps $steps --cmd "$cmd"

```
<font color="#dc4c3f">If you want to allocate GPUs, see the following usage guidelines for slurm.pl. DO NOT allocate GPU resources using **sbatch** command. </font><br/>

---

**It is not recommended to use *#SBATCH* command at the top of the running scripts like below.**
```
#!/bin/bash
#SBATCH -o job.%j.out
#SBATCH -J myFirstJob
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
```

## SLURM.PL USAGE

+ Basic usage of slurm.pl
    ```
    nodelist=node01   # specify one node for running your jobs
    # DO NOT specify more than one node in nodelist

    num_threads_per_job=2   # specify number of CPUs for one srun job
    exclude_nodelist=node0[4-7]   # exclude nodes for submitting jobs
    memory_limit=20G   # srun jobs would be killed at the moment exceeded this memory limit
    ngpu=2   # number of GPUs you scripts needed
    log=$somelog.log
    
    slurm.pl --quiet --nodelist=$nodelist --gpu $ngpu\
         --num-threads $num_threads_per_job --mem $memory_limit \
         $log $scripts(shell, python, etc.) [ paramlist]

    # slurm.pl --quiet --exclude=$exclude_nodelist --gpu $ngpu\
         --num-threads $num_threads_per_job --mem $memory_limit \
         $log $scripts(shell, python, etc.) [ paramlist]
    ```
## SLURM INTERACTIVE MODE
You might use slurm interactive mode to get resource allocation and run it locally if the cluster is drained frequently.For example:

```
srun -w node08 -N 1 -c 2 --gres=gpu:1 --pty bash --
```
 
Now you would be at node08 with a gpu allocated for you through slurm. There would be a `bash` task if you check slurm squeue.

After this, you may need to activate your python env again, and check the env before running your scripts locally by 'which python'.


## RUNNING KALDI SCRIPTS WITH SLURM
Kaldi scripts use **cmd.sh** to run distributed/parallel jobs and would automatically add GPU allocate parameters, so there is no need to add GPU related parameters in the **cmd.sh**.
Below is an example of **cmd.sh** at the project root folder
```
    export cmd="slurm.pl --quiet"
    export decode_cmd="slurm.pl --quiet --exclude=node0[4-7]"
    export train_cmd="slurm.pl --quiet --exclude=node0[1-2,4-9] --num-threads 2"
    ....
```

And source the cmd.sh in your running scripts.

```
    #!/bin/bash
    
    . cmd.sh
    ## other commands
```
## RUNNING PYTHON SCRIPTS WITH SLURM
Most python scripts require to specify which GPUs the scripts would use. To do so, you should:
Following are some tips for python training scripts using slurm to allocate GPU resources.
 1. Move your python scripts needed GPU resources to another shell script from the one submitted by sbatch. Here I use the WeNet train script as an example. 
     ```
     #### train.sh
     #!/bin/bash
     ## some params
       . tools/parse_options.sh || exit 1;
     ## some params

     gpu_id=$CUDA_VISIBLE_DEVICES

     python wenet/bin/train.py --gpu $gpu_id \
          --config $train_config \
          --data_type raw \
          --symbol_table $dict \
          --train_data $train \
          --cv_data $dev \
          ${checkpoint:+--checkpoint $checkpoint} \
          --model_dir $dir \
          --ddp.init_method $init_method \
          --ddp.world_size $ngpu \
          --ddp.rank $[ part-1 ] \
          --ddp.dist_backend $dist_backend \
          --num_workers 1 \
          $cmvn_opts \
          --pin_memory || exit 1;
      ```
``` gpu_id=$CUDA_VISIBLE_DEVICES ``` where **CUDA_VISIBLE_DEVICES** is automatically set by **slurm** in the running nodes. So the script uses the GPUs slurm allocates for it.

<font color="#dc4c3f">In the scripts, we should **NEVER** export the variable  **CUDA_VISIBLE_DEVICES** manually, like ``` export CUDA_VISIBLE_DEVICES="1,2,3" ```, and **NEVER** specify the GPU id for your scripts like  </font><br/>
``` 
    gpu_id="2"
    python $somewhere/train.py --gpu $gpu_id [--paramlist] 
    # here --gpu means the id of GPUs it will allocate, not the number of GPUs
```

 <font color="#dc4c3f">**WARNING**：If you set **CUDA_VISIBLE_DEVICES** yourself, you would be probably using the wrong GPUs and other users can still submit jobs to the GPUs you were using. This may crash both of the jobs or seriously affects the efficiency of the machine.  </font><br/>

        
 2. Edit the shell script where called the above script submitted by sbatch. 
     + The following example is for single thread training scripts like WeNet, where srun only allocate 1 GPU for each python training thread. 

     If multiple GPUs are needed because of large amount of training data or some other reasons, you can follow the Kaldi style distributed training scripts like below, which will start 2 srun jobs, each allocate 2 CPUs and 1 GPU.
      ```
         num_gpus=2
         # cmd="slurm.pl --quiet --nodelist=node01"
         $cmd --num-threads 2 --gpu 1 JOB=1:$num_gpus \
             $dir/log/train.JOB.log \
             train.sh \
             --train_config $train_config \
             --dict $dict \
             --train ./data/$train_set/data.list \
             --dev ./data/dev/data.list \
             --ngpu $num_gpus \
             --part JOB \
             --dist_backend $dist_backend \
             --checkpoint "$checkpoint" \
             --cmvn_dir ./data/$train_set/global_cmvn \
             $dir $init_method || exit 1;
      ```
  If your python scripts are multi-threads style, you can allocate multiple GPUs with one srun job.
     
   ```
         num_gpus=2
         threads=$[ num_gpus*2 ]
         # cmd="slurm.pl --quiet --nodelist=node01"
         $cmd --num-threads $threads --gpu $num_gpus \
         $dir/log/train.log \
             train.sh \
             --train_config $train_config \
             --dict $dict \
             --train ./data/$train_set/data.list \
             --dev ./data/dev/data.list \
             --ngpu $num_gpus \
             --part $something \
             --dist_backend $dist_backend \
             --checkpoint "$checkpoint" \
             --cmvn_dir ./data/$train_set/global_cmvn \
             $dir $init_method || exit 1;
   ```

<big>**NOTICE**</big>
While submit GPU jobs, you would better set ```--num-threads 2*$num_gpus``` for both **Kaldi** or **Python** scripts which can help a lot for the efficiency use of GPUs.

NSCC Singularity:
Warning: As NSCC uses a very old kernel, it is incompatible with most singularity images, so you need to search for the right one

you need to run a Singularity container inside NSCC if you want to install packages in the container directly, and you will need a Singularity image for that.
You may either find the images in NSCC or find one and pull it using the below commands:

$ singularity remote login SylabsCloud
$ singularity search <keyword-for-image>
$ singularity pull <image-name>:<tag>


Sometimes You may need to edit an image. The process to follow is (with sudo): 

1. extract singularity image,
    $ singularity build --sandbox /path/to/sandbox imagename.sif
2. launch image in write mode singularity exec -w /path/to/sandbox /bin/bash
3. Install all packages required 
4. repack the image 
    $ singularity build <new-image-name.sif> /path/to/sandbox


Alternatively, use docker to download an image and convert it to .sif
Only works the docker image users the same kernel version as NSCC
$ docker pull <docker-image>
$ docker images # Check the image id
$ docker save <image-id> -o /some/save-path.tar
$ sudo singularity build --tmpdir <tmp-dir-of-enough-space> <new-name>.sif docker-archive:<path-of-docker-image-tar>

NSCC uses K80t GPUS. To use pytorch higher versions with older gpus:
https://blog.nelsonliu.me/2020/10/13/newer-pytorch-binaries-for-older-gpus/
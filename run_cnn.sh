#!/bin/bash
## Display start time
#--------------------
echo
START=$(date +%s)
echo Simulation starts at: `date`
MODE_TEST_DEBUG=$1
namethisfic=`basename "$0"`
curdir="$( cd "$( dirname "${BASH_SOURCE[0] }" )" && pwd )"
# two variables you need to set
pdnndir=$curdir/Software/pdnn  # pointer to PDNN
export PYTHONPATH=$PYTHONPATH:$pdnndir
export PYTHONPATH=$PYTHONPATH:$curdir/Scripts
export PYTHONPATH=$PYTHONPATH:$curdir/interface_latex
device=cpu
pythoncmd="nice -n19  /usr/bin/python -u"

######################## FEATURES PARAMS ##############################
classes="{Noise,Conversation,Shouting}"
typeparam="MFCC"
window_step=0.010 # in seconds, hop size between two successive mfcc windows
window_size=0.025 # in seconds, size of MFCC window
highfreq='20000' # maximal analysis frequency for mfcc
lowfreq='50' # minimal analysis frequency for mfcc
size='40' # number of mfcc or spectral coef
N='10' #contextual window
slide='5'
threshold=10000
compute_deltas="False"
cnn_arch="1x10x40:150,8x10,p2x2:100,1x8,1x2,f"
coucheDNN="256:3"
layerNumberDNN='3'
lambda="C:0.08:2" #"D:0.1:0.8:0.2,0.05" #

###################################################################
rep_classes=`echo $classes | sed -e 's/,/_/g' -e 's/.//;s/.$//'`
wst=$(echo "$window_step * 1000" |bc -l)
wsi=$(echo "$window_size * 1000" |bc -l)
window_steptxt=${wst/.000/m}
window_sizetxt=${wsi/.000/m}
coucheCNNtxt=$cnn_arch
coucheDNNtxt=$layerNumberDNN"x"$coucheDNN
param_test="{$window_step,$window_size,$highfreq,$lowfreq,$size,$N,$slide,$threshold,$compute_deltas}"
param_txt=$typeparam'_'$window_steptxt'_'$window_sizetxt'_'$highfreq'_'$lowfreq'_'$size'_'$N'_'$slide

# export environment variables
export PYTHONPATH=$PYTHONPATH:$pdnndir
export THEANO_FLAGS=mode=FAST_RUN,device=$device,floatX=float32,openmp='True'

if [ $MODE_TEST_DEBUG -eq 1 ] ; then
    echo " !!! MODE DEBUG - TOUT LE CONTENU DE $curdir/Features VA ETRE EFFACE !!! "
    echo " \\t CTRL + C pour arreter le processus et mettre MODE_TEST_DEBUG=0 dans rbm_audio_classification.sh"
    echo " \\t N'importe quelle touche pour continuer"
##    read nimportequoi
fi
if [ $MODE_TEST_DEBUG -eq 1 ] ; then
    rm -rf $curdir/Features/*
fi
flag=0
if [ "$(ls $curdir/Features)" ] ; then
    if [ -d $curdir/Features/$rep_classes ]; then
        if [ -d $curdir/Features/$rep_classes/$param_txt ]; then
          echo "echo 'data already prepared...'"
          dir_classes="$curdir/Features/$rep_classes"
          rep_classes="$dir_classes/$param_txt"
        else
          dir_classes="$curdir/Features/$rep_classes"
          rep_classes="$dir_classes/$param_txt"
          echo "creation  de " $rep_classes
          mkdir $rep_classes
          echo "Preparing datasets"
          cp $curdir/$namethisfic $rep_classes/$namethisfic
          flag=1
        fi
    else
      dir_classes="$curdir/Features/$rep_classes"
      echo "creation  de " $dir_classes
      mkdir $dir_classes
      rep_classes="$dir_classes/$param_txt"
      echo "creation  de " $rep_classes
      mkdir $rep_classes
      echo "Preparing datasets"
      cp $curdir/$namethisfic $rep_classes/$namethisfic
       flag=1
    fi
else
#  echo "Preparing datasets"
  dir_classes="$curdir/Features/$rep_classes"
  echo "creation  de " $dir_classes
  mkdir $dir_classes
  rep_classes="$dir_classes/$param_txt"
  echo "creation  de " $rep_classes
  mkdir $rep_classes
  cp $curdir/$namethisfic $rep_classes/$namethisfic
  echo "Preparing datasets"
  flag=1
fi

######################## CREATE DATASET ###############################
echo $param_test > $rep_classes/log.txt
echo $rep_classes
STEP1_START=$(date +%s)
if [ $flag -eq 1 ] ; then
    python $curdir/Scripts/format_data_cnn.py --data_type "train" --rep_test $rep_classes \
                        --param $param_test --classes $classes
    python $curdir/Scripts/format_data_cnn.py --data_type "test" --rep_test $rep_classes \
                        --param $param_test --classes $classes
    python $curdir/Scripts/format_data_cnn.py --data_type "valid" --rep_test $rep_classes \
                        --param $param_test --classes $classes
fi
STEP1_END=$(date +%s)

######################## TRAIN CNN ###############################
if [ -d $rep_classes/$coucheCNNtxt-$coucheDNNtxt ]; then
    echo "Model DBN $coucheCNNtxt-$coucheDNNtxt exist."
    echo "The DBN model will be loaded"
else
    mkdir "$rep_classes/$coucheCNNtxt-$coucheDNNtxt"
    cp $curdir/$namethisfic $rep_classes/$coucheCNNtxt-$coucheDNNtxt/$namethisfic
fi
echo "Training the CNN model ..."
STEP3_START=$(date +%s)
python $pdnndir/cmds/run_CNN.py --train-data "$rep_classes/train.pickle.gz" \
                                --valid-data "$rep_classes/valid.pickle.gz" --conv_nnet_spec $cnn_arch\
                                --nnet-spec $coucheDNN --wdir $rep_classes/$coucheCNNtxt/$coucheDNNtxt \
                                --l2-reg 0.001 --lrate $lambda --model-save-step 10 --ptr-layer-number 0 \
                                --param-output-file  $rep_classes/$coucheCNNtxt-$coucheDNNtxt/cnn.param \
                                --cfg-output-file $rep_classes/$coucheCNNtxt-$coucheDNNtxt/cnn.cfg \
                                > $rep_classes/$coucheCNNtxt-$coucheDNNtxt/cnn.training.log
STEP3_END=$(date +%s)

######################## CLASSIFICATION ON TEST DATASET ###############################
echo "Do classification on the test set ..."
STEP4_START=$(date +%s)
python $pdnndir/cmds/run_Extract_Feats.py --data "$rep_classes/test.pickle.gz" \
                                          --nnet-param  $rep_classes/$coucheCNNtxt-$coucheDNNtxt/cnn.param \
                                          --nnet-cfg  $rep_classes/$coucheCNNtxt-$coucheDNNtxt/cnn.cfg \
                                          --output-file "$rep_classes/$coucheCNNtxt-$coucheDNNtxt/cnn.classify.pickle.gz" --layer-index -1 \
                                          --batch-size 100 >  $rep_classes/$coucheCNNtxt-$coucheDNNtxt/cnn.testing.log;
STEP4_END=$(date +%s)

mkdir $rep_classes/$coucheCNNtxt-$coucheDNNtxt/tex
STEP5_START=$(date +%s)
echo $rep_classes
python $curdir/Scripts/show_results.py --pred_file "$rep_classes/$coucheCNNtxt-$coucheDNNtxt/cnn.classify.pickle.gz" \
           --datapath $rep_classes \
           --classes $classes \
           --filepath $rep_classes/$coucheCNNtxt-$coucheDNNtxt/tex\
           --nametex "Confusion_matrix"
STEP5_END=$(date +%s)

#cd $rep_classes/$coucheCNNtxt/$coucheDNNtxt/tex
#pdflatex Confusion_matrix.tex
#cp Confusion_matrix.pdf $rep_classes/$coucheCNNtxt/$coucheDNNtxt/Confusion_matrix.pdf
#cp Confusion_matrix.tex $rep_classes/$coucheCNNtxt/$coucheDNNtxt/tex/Confusion_matrix.tex
#cp table.tex $rep_classes/$coucheCNNtxt/$coucheDNNtxt/tex/table.tex
#rm Confusion_matrix.pdf
#rm Confusion_matrix.tex
#rm Confusion_matrix.aux
#rm Confusion_matrix.log
#rm table.tex
#rm table.aux

## Display end time
#------------------
echo
STOP=$(date +%s)
echo Simulation ends at `date `

## Compute and display elapsed time
#----------------------------------
echo
DIFF=$(( $STOP - $START ))
DAYS=$(( $DIFF / (60*60*24) ))
HR=$(( ($DIFF - $DAYS*60*60*24) / (60*60) ))
MIN=$(( ($DIFF - $DAYS*60*60*24 - $HR*60*60) / (60) ))
SEC=$(( $DIFF - $DAYS*60*60*24 - $HR*60*60 - $MIN*60 ))
echo "Elapsed time :: $DAYS jours $HR heures $MIN minutes et $SEC secondes"
echo

echo "$HOSTNAME $OMP_NUM_THREADS $(( $STEP1_END - $STEP1_START )) $(( $STEP2_END - $STEP2_START )) $(( $STEP3_END - $STEP3_START )) $(( $STEP4_END - $STEP4_START )) $(( $STEP5_END - $STEP5_START )) $(( $STOP - $START ))" >> results.log
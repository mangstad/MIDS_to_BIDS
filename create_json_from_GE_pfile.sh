#!/bin/bash

FILE=$1

#need to set the rdgehdr path if not on path
#if it is already on your path leave this blank
RDGEHDRDIR='/home/slab/users/mangstad/repos/MIDS_to_BIDS/'

tmpfile=$(mktemp /tmp/create_json_from_GE_pfile.XXXXXX)

${RDGEHDRDIR}rdgehdr ${FILE} > ${tmpfile}

TR=`grep -a "Pulse repetition time" ${tmpfile} | sed 's/...Pulse.*://' | awk '{print $1/1000000.0}'`
TE=`grep -a "...Pulse echo time" ${tmpfile} | sed 's/....*://' | awk '{print $1/1000000.0}'`
EES=`grep -a "...Effective echo spacing" ${tmpfile} | sed 's/....*://' | awk '{print $1/1000000.0}'`

#phase encode direction, get direction based on frequency encode, direction based on blipval
#slice encode direction, how to get this? User variable 9 per krisanne, 0 is P-A, 1 is A-P
BLIPVAR=`grep -a "...User variable 9:" ${tmpfile} | sed 's/....*://'`
PED="+"
if [ $BLIPVAR -eq 0 ]; then
    PED="+"
else
    PED="-"
fi
#how to find the phase encode axis?
#first let's get the frequency, it's easier
#...Frequency direction: 1 (left/right)
#first axis, but how can we be sure it's + vs -, maybe doesn't matter since we don't actually need this
FED=`grep -a "...Frequency direction" ${tmpfile} | sed 's/....*://' | awk '{print $1}'`

#we'll assume slice encode is axial for now
#hacky, but look at points in pass and compare which axis has the changing values
TMP_I=`grep -a "point 1" ${tmpfile} | sed 's/point 1://' | sed 's/,//g' | awk '{print $1}'`
TMP_J=`grep -a "point 1" ${tmpfile} | sed 's/point 1://' | sed 's/,//g' | awk '{print $2}'`
TMP_K=`grep -a "point 1" ${tmpfile} | sed 's/point 1://' | sed 's/,//g' | awk '{print $3}'`

ARR_I=($TMP_I)
ARR_J=($TMP_J)
ARR_K=($TMP_K)

COUNT=`expr ${#ARR_I[@]} - 1`
DEV_I=0
DEV_J=0
DEV_K=0

for i in `seq 0 ${COUNT}`
do
    tmp=`echo ${ARR_I[i]} - ${ARR_I[0]} | bc`
    DEV_I=`echo ${DEV_I} + ${tmp#-} | bc`
    tmp=`echo ${ARR_J[i]} - ${ARR_J[0]} | bc`
    DEV_J=`echo ${DEV_J} + ${tmp#-} | bc`
    tmp=`echo ${ARR_K[i]} - ${ARR_K[0]} | bc`
    DEV_K=`echo ${DEV_K} + ${tmp#-} | bc`
done



#Slice 0, pass = 0, slice in pass = 1
#Slice 1, pass = 0, slice in pass = 6
SACQ=`grep -a "Slice [0-9]*, pass" ${tmpfile} | sed 's/Slice //' | sed 's/, pass = 0, slice in pass = / /'`
SACQa=( $SACQ )
COUNT=`expr ${#SACQa[@]} / 2`
idx=0
for i in `seq 1 $COUNT`
do
    SLICE[${i}]=`expr ${SACQa[${idx}]} + 1`
    idx=`expr ${idx} + 1`
    ORDER[${i}]=${SACQa[${idx}]}
    idx=`expr ${idx} + 1`
done

#need to grab multiband acceleration factor, might be rhuser6
#then expand above slice and order vectors for all slices

MBF=`grep -a "...rhuser6:" ${tmpfile} | sed 's/....*://'`

#now calculate slice times as TR/#slices * (slice#-1) and replicate them MBF times
SDT=`echo "scale=5;${TR}/${#SLICE[@]}" | bc`

idx=0
for j in `seq 1 $MBF`
do
    for i in `seq 1 $COUNT`
    do
	SAT[${idx}]=`echo "scale=5;(${ORDER[${i}]}-1)*$SDT" | bc`
	idx=`expr ${idx} + 1 `
    done
done

#now output it all in json format
echo "{" 
echo -e "\t\"ReptititonTime\": ${TR}," 
echo -e "\t\"EchoTime\": ${TE}," 
echo -e "\t\"EffectiveEchoSpacing\": ${EES},"
echo -e "\t\"PhaseEncodingDirection\": \"j${PED}\"," 
echo -e "\t\"MultibandAccerlationFactor\": ${MBF}," 
echo -ne "\t\"SliceTiming\": [ ${SAT[0]}"
COUNT=`expr ${#SAT[@]} - 1`
for i in `seq 1 $COUNT`
do
    echo -n ",${SAT[i]}"
done
echo "]"
echo "}"

rm ${tmpfile}

#still todo for recommended bids stats
#Manufacturer
#ManufacturersModelName
#DeviceSerialNumber ...Unique system ID: 0007347633TMRFIX
#StationName
#SoftwareVersions #Genisis version?
#MagneticFieldStrength
#ReceiveCoilName #logicalCoilName?
#ReceiveCoilActiveElements #channel translation map?
#GradientSetType
#MRTransmitCoilSequence
#MatrixCoilMode
#CoilCombinationMethod

#PulseSequenceType
#ScanningSequence
#SequenceVariant
#ScanOptions
#SequenceName #Pulse sequence name
#PulseSequenceDetails
#NonlinearGradientCorrection

#NumberShots
#ParallelReductionFactorInPlane
#ParallelAcquisitionTechnique
#PartialFourier
#PartialFourierDirection
#PhaseEncodingDirection
#EffectiveEchoSpacing *
#TotalReadoutTime #required for fieldmap with 2 pe directions

#EchoTime *
#InversionTime
#SliceTiming *
#SliceEncodingDirection #Most-like plane?
#DwellTime

#FlipAngle #Flip angle for GRASS scans (deg)?
#MultibandAccelerationFactor *

#InstitutionName ...Hospital name: U Of M research
#InstitutionAddress
#InstitutionalDepartmentName

#ReptitionTime *
#TaskName #Series description?

#NumberOfVolumesDiscardedByScanner
#NumberOfVolumesDiscardedByUser
#DelayTime
#AcquisitionDuration
#DelayAfterTrigger


#others, display FOV
#matrix size #...Image matrix size - x: 96
#pixel size
#slice thickness
#spacing between
#Frequency direction

#Plane type
#Oblique plane
#scout type
#Current phase for this image

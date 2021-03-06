#!/bin/sh -w

###############################################################################################################
#                                                                                                             #
#                                          Nanopore Sequencing Pipeline                                       #
#                                                                                                             #
###############################################################################################################


###########################################                                                                                                         
## Step 0:  colors                       ##
###########################################

# Colors for text
red='\033[0;31m'
green='\033[0;32m'
nc='\033[0m'
blue='\033[0;34m'


echo -e "${blue} color ${red}test ${green} test ${nc}..."
sleep 10

# Command line options
while : ; do
    case $1 in
        -i)
            shift
            input=$1
            shift
            ;;
        -o)
            shift
            out=$1
            shift
            ;;            
        *)  
            if [ -z "$1" ]; then break; fi
            ERR=1
            shift
            ;;
         
    esac
done

if [[ "${input: -1}" == "/" ]]; then
    c=${input::-1}
fi

if [[ "${out: -1}" == "/" ]]; then
    out=${out::-1}
fi


# Creates output directory if it does not exist
if [ ! -d "$out" ]; then
mkdir -p $out/Temp 
mkdir -p $input
fi

###########################################                                                                                                         
## Step 1:  Defining work environment    ##
###########################################

## merge .fastq files via cat *.fastq > 01_reads.fastq

## Important, fastq files generated by albacore should be renamed as 01_reads.fastq before start ##

## /../ should be replaced by the directory where the files are saved 

input="$input"

output="$out/"

raw="/run_1/fast5_pass/"

Step1_R="/run_1/R/"

Step1_in="/run_1/fast5/"

Step1_out="$out/step_1/"

quality_control="$out/quality_control/"

trimming="$out/trimming/"

mapping="$out/mapping/"

assembly="$out/assembly/"

polished="/$out/polished/"

annotation="/$out/annotation/"

mkdir -p $output
mkdir -p $quality_control
mkdir -p $trimming
mkdir -p $mapping
mkdir -p $assembly
mkdir -p $polished
mkdir -p $annotation

#chmod 755 -R  /home/benedikth/vibriophage_seq/run_1/fast5_pass_guppy


#######################################################
##computing parameters                               ##
#######################################################
threads=24
mem_size='96G'




#######################################################
## Step 2:  First quality assessment                 ##
#######################################################

echo -e "${blue}Running first quality control ${nc} ..."

fastqc -t $threads $input"01_reads.fastq" -o $quality_control --nano 

Rscript $Step1_R"minion_qc.R" -i $Step1_in"sequencing_summary.txt" -o $Step1_out



#######################################################
## Step 3:  Adapter removal using PoreChop           ##
#######################################################

echo -e "${blue}trimming adapter and barcodes ${nc}..."

# barcode trimming
porechop -i $input"01_reads.fastq" -t $threads -v 2 -b $trimming --barcode_threshold 75 --discard_unassigned > $trimming"03_porechop.log"
#cat $output"03_porechop.log" | more



#######################################################
## Step 4:  Second quality assessment with FastQC    ##
#######################################################

fastqc -t $threads $trimming -o $quality_control --nano 



####################################################
## Step 5:  Assembling the genome using pomoxis   ##
####################################################

# start the pomoxis suite
. /opt/pomoxis/venv/bin/activate 
echo -e "${blue}pomoxis will utilize a few steps for mapping, assembly and polishng ${nc}..."
echo -e "${blue}..."
echo -e "${blue}..."
echo -e "${blue}..."

echo -e "${blue}mapping in process ${nc} ..."
echo -e "${blue}..."
echo -e "${blue}..."
echo -e "${blue}..."


# map the fastq against each other to find overlaps
minimap2 -x ava-ont -t $threads $trimming"BC01.fastq" $trimming"BC01.fastq" | gzip -1 > $mapping"04_BC01_mapping.paf.gz"
minimap2 -x ava-ont -t $threads $trimming"BC02.fastq" $trimming"BC02.fastq" | gzip -1 > $mapping"04_BC02_mapping.paf.gz"
minimap2 -x ava-ont -t $threads $trimming"BC03.fastq" $trimming"BC03.fastq" | gzip -1 > $mapping"04_BC03_mapping.paf.gz"
minimap2 -x ava-ont -t $threads $trimming"BC04.fastq" $trimming"BC04.fastq" | gzip -1 > $mapping"04_BC04_mapping.paf.gz"


miniasm -f $trimming"BC01.fastq" $mapping"04_BC01_mapping.paf.gz" > $mapping"04_BC01_miniasm_reads.gfa"
miniasm -f $trimming"BC02.fastq" $mapping"04_BC02_mapping.paf.gz" > $mapping"04_BC02_miniasm_reads.gfa"
miniasm -f $trimming"BC03.fastq" $mapping"04_BC03_mapping.paf.gz" > $mapping"04_BC03_miniasm_reads.gfa"
miniasm -f $trimming"BC04.fastq" $mapping"04_BC04_mapping.paf.gz" > $mapping"04_BC04_miniasm_reads.gfa"

echo -e "${green}mapping finished"

# convert .gfa to .fasta
awk '$1 ~/S/ {print ">"$2"\n"$3}' $mapping"04_BC01_miniasm_reads.gfa" > $assembly"05_BC01_miniasm_reads.fasta"
awk '$1 ~/S/ {print ">"$2"\n"$3}' $mapping"04_BC02_miniasm_reads.gfa" > $assembly"05_BC02_miniasm_reads.fasta"
awk '$1 ~/S/ {print ">"$2"\n"$3}' $mapping"04_BC03_miniasm_reads.gfa" > $assembly"05_BC03_miniasm_reads.fasta"
awk '$1 ~/S/ {print ">"$2"\n"$3}' $mapping"04_BC04_miniasm_reads.gfa" > $assembly"05_BC04_miniasm_reads.fasta"


echo -e "${blue}ssembly in process"
echo -e "${blue}..."
echo -e "${blue}..."
echo -e "${blue}..."

# assembling
minimap2 $assembly"05_BC01_miniasm_reads.fasta" $trimming"BC01.fastq" > $assembly"05_BC01_minimap_reads.paf"
minimap2 $assembly"05_BC02_miniasm_reads.fasta" $trimming"BC02.fastq" > $assembly"05_BC02_minimap_reads.paf"
minimap2 $assembly"05_BC03_miniasm_reads.fasta" $trimming"BC03.fastq" > $assembly"05_BC03_minimap_reads.paf"
minimap2 $assembly"05_BC04_miniasm_reads.fasta" $trimming"BC04.fastq" > $assembly"05_BC04_minimap_reads.paf"

echo -e "${green}assembly finished"
echo -e "${blue}polishing in process"
echo -e "${blue}..."
echo -e "${blue}..."
echo -e "${blue}..."

# polish the assembly
racon -t $threads $trimming"BC01.fastq" $assembly"05_BC01_minimap_reads.paf" $assembly"05_BC01_miniasm_reads.fasta" > $polished"06__BC01_racon.fasta"
racon -t $threads $trimming"BC02.fastq" $assembly"05_BC02_minimap_reads.paf" $assembly"05_BC02_miniasm_reads.fasta" > $polished"06__BC02_racon.fasta"  
racon -t $threads $trimming"BC03.fastq" $assembly"05_BC03_minimap_reads.paf" $assembly"05_BC03_miniasm_reads.fasta" > $polished"06__BC03_racon.fasta"  
racon -t $threads $trimming"BC04.fastq" $assembly"05_BC04_minimap_reads.paf" $assembly"05_BC04_miniasm_reads.fasta" > $polished"06__BC04_racon.fasta"  

echo -e "${green}polishing finished"

echo -e "${green}############################################################################"
echo -e "${green}#                                                                          #"
echo -e "${green}#                                                                          #"
echo -e "${green}#                                                                          #"
echo -e "${green}#                             ASSEMBLY COMPLETE                            #"
echo -e "${green}#                                                                          #"
echo -e "${green}#                                                                          #"
echo -e "${green}#                                                                          #"
echo -e "${green}############################################################################"
deactivate


###################################################
## Step 6:  Annotation using prokka              ##
###################################################


###################################################
## Step 7:  Third quality control using QUAST    ##
###################################################

# quast.py -t $threads -o $Step10_QC $polished"10_racon.fasta" $assembly"09_miniasm_reads.fasta"

# include step for removing temp data  

# map the fastq against each other to find overlaps








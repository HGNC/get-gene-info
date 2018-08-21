# get-gene-info.pl
Retrieving HGNC gene symbol reports (human genes only) via a list of gene IDs.
(mac or linux compatible only).

## SYNOPSIS
```
./get-gene-info.pl -type=ncbi -file=ids.txt -column=hgnc_id -column=symbol

Options:
  -help            Brief help message.
  -man             Full documentation.
  -type            Gene ID type within the file.
  -file            File name containing the list of gene IDs.
  -column          This argument can be used multiple times. Will
                   retrieve the columns specified from the gene report.
```
## DESCRIPTION
A perl script which will return JSON objects containing HGNC gene
information for each gene ID specified in the user provided file. The
script utilises the HGNC REST service and allows the user to retrieve
any data that is displayed within our gene symbol reports.

## OPTIONS
### -help
Print a brief help message and exits.

### -man
Prints the manual page and exits.

### -type    
The type of gene IDs found within the provided file. Type can be
one of the following:

    ncbi               for NCBI gene IDs eg. 673
    hgnc               for HGNC gene IDs eg. HGNC:1097
    ensembl            for ensembl gene IDs eg. ENSG00000157764
    symbol             for HGNC approved symbol eg. TP53

### -file
The path of the txt file that contains a list of gene IDs of the
type seen above

### -column
Use this flag for each column you want to appear within the output.
Columns will be tab separated. For a list of columns that you can
use please refer to either our 
[REST help page](https://www.genenames.org/help/rest-web-service-help#Stored_fields)
or using the [info](http://rest.genenames.org/info) REST service command and use any
columns under "storedFields".

## REQUIREMENTS
This will only work for macs and linux machines. Git must be installed.

### Mac users
If you haven't install git or xcode and you initiate a `git clone`, your mac
may ask you to install xcode. Please install this app and try to `git clone`
once again.

## INSTALL
To install this command line tool, clone this project into your directory of choice:
```bash
git clone https://github.com/HGNC/get-gene-info.git
```
Once cloned you then need to run the install script:
```bash
./install.sh
```
The install script will download all the required modules needed for the script and
will test the script. Once successfully install you may use the script as described
above.

### Install video
<a href="http://www.youtube.com/watch?feature=player_embedded&v=Zrn5l6fTVH0&cc_load_policy=1
" target="_blank"><img src="http://img.youtube.com/vi/Zrn5l6fTVH0/0.jpg" 
alt="Install video" width="480" height="360" border="10" /></a>

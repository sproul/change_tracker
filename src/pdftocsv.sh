#!/bin/bash
while [ -n "$1" ]; do
        case "$1" in
                -dir)
                        shift
                        dir="$1"
                        find "$dir" -name '*.pdf' |
                        while read fn; do
                                echo.clean "$0 \"$fn\""
                                $0       "$fn"
                        done
                        exit
                ;;
                *)
                        break
                ;;
        esac
        shift
done

pdf_fn="$1"
csv_fn=`sed -e 's/pdf$/csv/' <<< $pdf_fn`
jar=`dirname "$0"`/../jar/tabula-1.0.2-jar-with-dependencies.jar
case "$OS" in
        win*)
                mixed_pdf_fn=`cygpath --mixed "$pdf_fn"`
                jar=`cygpath --mixed "$jar"`
        ;;
        *)
                mixed_pdf_fn=$pdf_fn
        ;;
esac
echo "From $pdf_fn generating $csv_fn"
stderr=`mktemp`
trap "rm $stderr" EXIT

if ! java -jar "$jar" --pages=all "$mixed_pdf_fn" 2> $stderr | tr -dC '[:print:]\t\n' > "$csv_fn"; then
        echo "$0: tabula java -jar $jar --pages=all $mixed_pdf_fn | tr -dC '[:print:]\t\n' > $csv_fn failed, exiting..." 1>&2
        cat $stderr
        exit 1
fi

exit
$dp/git/fin_doc_parser/src/pdftocsv.sh ../test_docs/MCBI_Q2_2018_Report.pdf
l ../test_docs/MCBI_Q2_2018_Report.*
exit
$dp/git/fin_doc_parser/src/pdftocsv.sh -dir ../test_docs
exit
c7 $DOWNLOADS/parser
$dp/git/fin_doc_parser/src/pdftocsv.sh -dir $DOWNLOADS/parser
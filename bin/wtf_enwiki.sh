#!/bin/sh

IFS=$'\n'

mkdir -p enwiki/page

# Extract core info from people pages (other that QEII
# TODO: also include current legislators
# TODO: include people who left office very recently

echo "pageid,title" > enwiki/index.csv

for page in $(qsv search -s end -v . html/holders21.csv | fgrep -v Q9682, | qsv select enwiki | qsv search . | qsv dedup | qsv sort | qsv behead); do
  echo $page
  json=$(printf '"%s"' "$page" | xargs wtf_wikipedia)
  pageid=$(printf '%s' "$json" | jq -r .pageID)
  title=$(printf '%s' "$json" | jq -r .title)
  printf '%s' "$json" | jq -r '.sections[].infoboxes[]? | to_entries | map({ (.key): .value.text }) | add' | egrep -v '"(image|caption)":'  > enwiki/$pageid
  echo "$pageid,\"$title\"" >> enwiki/index.csv
done

qsv select 1,2 enwiki/index.csv | qsv sort -N -s pageid  | ifne tee enwiki/index.csv

# Extract all info from pages listed in 'wpwatch' files

for page in $(find . -name 'wpwatch*.txt' -exec egrep -h '^http' {} \+)
do
  echo $page
  json=$(printf '"%s"' "$page" | xargs wtf_wikipedia)
  pageid=$(printf '%s' "$json" | jq -r .pageID)
  printf '%s' "$json" | jq -r . > enwiki/page/$pageid
done

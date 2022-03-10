#!/bin/sh

IFS=$'\n'

mkdir -p enwiki/page

# Extract core info from people pages (other that QEII

for page in $(fgrep -v Q9682 html/current.csv | qsv select enwiki | qsv search . | qsv dedup | qsv sort | qsv behead); do
  echo $page
  json=$(printf '"%s"' "$page" | xargs wtf_wikipedia)
  pageid=$(printf '%s' "$json" | jq -r .pageID)
  printf '%s' "$json" | jq -r '.sections[].infoboxes[]? | to_entries | map({ (.key): .value.text }) | add' > enwiki/$pageid
done

# Extract all info from pages listed in 'wpwatch' files

for page in $(find . -name 'wpwatch*.txt' -exec egrep -h '^http' {} \+)
do
  echo $page
  json=$(printf '"%s"' "$page" | xargs wtf_wikipedia)
  pageid=$(printf '%s' "$json" | jq -r .pageID)
  printf '%s' "$json" | jq -r . > enwiki/page/$pageid
done

#!/bin/sh

TMPFILE=$(mktemp)
HOLDERS=$(mktemp)
UNDATED=$(mktemp)
RAWBIOS=$(mktemp)
RAWPOSN=$(mktemp)
BIO_CSV=$(mktemp)
ENUM_PS=$(mktemp)
EXTD_21=$(mktemp)
FAMINFO=$(mktemp)
FAMNAME=$(mktemp)

PERSON_PROPS="labels,P31,P18,P21,P27,P1559,P1477,P2561,P735,P734,P1950,P5056,P2652,P569,P19,P570,P22,P25,P26,P40,P3373,P39,P69,P511,P102,P3602,P22,P25,P26,P40,P3448,P451,P3373,P1290,P8810,P1038,sitelinks"
POSITION_PROPS="en,P571,P576,P580,P582,P1308,P17,P1001,P2354,P2098,P1365,P1366,P155,P156,sitelinks"

# Data about each wanted position
qsv cat rows wikidata/*-positions.csv | qsv enum > $ENUM_PS
qsv select position wikidata/wanted-positions.csv |
  qsv sort |
  qsv behead |
  wd data --props $POSITION_PROPS --simplify --time-converter simple-day --keep qualifiers,nontruthy,ranks,nondeprecated,richvalues > $RAWPOSN

# TODO: compare P1308 (officeholders) with P39s
jq -r 'def highest(array): (array | sort_by(.rank) | reverse | first.value);
  [
    .id,
    .labels.en,
    highest(.claims.P17),
    highest(.claims.P1001),
    highest(.claims.P2098),
    highest(.claims.P2354),
    highest([.claims.P571,  .claims.P580] | flatten).time,
    highest([.claims.P576,  .claims.P582] | flatten).time,
    highest([.claims.P1365, .claims.P155] | flatten),
    highest([.claims.P1366, .claims.P156] | flatten),
    (try (.sitelinks.enwiki) catch null)
  ] | @csv' $RAWPOSN |
  qsv rename -n 'id,position,country,jurisdiction,deputy,list,start,end,before,after,enwiki' |
  qsv dedup |
  qsv join position $ENUM_PS id - |
  qsv sort -N -s index |
  qsv select 4- > html/positions.csv

# Holders of each wanted position
qsv cat rows wikidata/*-positions.csv |
  qsv select position |
  qsv behead |
  xargs wd sparql pcb/holders.js -f csv > $TMPFILE
sed -e 's#http://www.wikidata.org/entity/##g' -e 's/T00:00:00Z//g' $TMPFILE > $HOLDERS

# Un-dated holders
qsv select position wikidata/wanted-positions.csv |
  qsv behead |
  xargs wd sparql pcb/unddated.js -f csv > $TMPFILE
sed -e 's#http://www.wikidata.org/entity/##g' -e 's/T00:00:00Z//g' $TMPFILE > $UNDATED

# Biographical info for officeholders
qsv select person $HOLDERS |
  qsv dedup |
  qsv sort |
  qsv behead |
  wd data --props $PERSON_PROPS --simplify --time-converter simple-day --keep qualifiers,nontruthy,ranks,nondeprecated,richvalues > $RAWBIOS

echo "id,name,gender,dob,dobp,dod,dodp,image,enwiki" > $BIO_CSV
jq -r 'def highest(array): (array | sort_by(.rank) | reverse | first.value);
  [
    .id,
    .labels.en // first(.labels[]),
    highest(.claims.P21),
    if highest(.claims.P569).precision >= 9 then highest(.claims.P569).time else null end,
    highest(.claims.P569).precision,
    highest(.claims.P570).time,
    highest(.claims.P570).precision,
    highest(.claims.P18),
    (try (.sitelinks.enwiki) catch null)
  ] | @csv' $RAWBIOS |
  sed -e 's/Q6581097\|Q2449503/male/' -e 's/Q6581072\|Q15145779\|Q1052281/female/' -e 's/Q189125/transgender/' -e 's/Q301702/two-spirt/' >> $BIO_CSV

# Family of officeholders
# TODO: dates? other relationships.
jq -r '{
    id: .id,
    name: (.labels.en // first(.labels[])),
    family: {
      father: [(.claims.P22[] | .value)],
      mother: [(.claims.P25[] | .value)],
      parent: [(.claims.P8810[] | .value)],
      stepparent: [(.claims.P3448[] | .value)],
      godparent: [(.claims.P1290[] | .value)],
      sibling: [(.claims.P3373[] | .value)],
      spouse: [(.claims.P26[] | .value)],
      partner: [(.claims.P451[] | .value)],
      child: [(.claims.P40[] | .value)],
      relative: [(.claims.P1038[] | .value)],
    }
}' $RAWBIOS | jq -s . > $FAMINFO
jq -r '.[] | .family | add | .[]' $FAMINFO  | sort | uniq | egrep Q | xargs wd data --props labels --simplify |
  jq -r '[.id, .labels.en // first(.labels[])] | @csv' | qsv rename -n 'id,name' > $FAMNAME
ruby pcb/relations.rb $FAMINFO $FAMNAME > html/family.csv

# Generate holders21.csv, keeping position order from wanted-positions
qsv join position $ENUM_PS position $HOLDERS |
  qsv select index,position,title,person,start,end,prev,next |
  qsv join person - id $BIO_CSV |
  qsv sort -s person |
  qsv sort -s start |
  qsv sort -N -s index |
  qsv select position,title,name,person,start,end,gender,dob,dod,image,enwiki,prev,next |
  qsv rename positionid,position,person,personID,start,end,gender,DOB,DOD,image,enwiki,prev,next > $EXTD_21

# Only include legislative members in legislators.csv
qsv join position wikidata/legislative-positions.csv position $HOLDERS |
  qsv select position,title,person,start,end,prev,next |
  qsv join person - id $BIO_CSV |
  qsv sort -s person |
  qsv sort -s start |
  qsv sort -s position |
  qsv select title,name,person,start,end,gender,dob,dod,image,enwiki |
  qsv rename position,person,personID,start,end,gender,DOB,DOD,image,enwiki | uniq > html/legislators.csv

# Remove legislative members to create holders21.csv
qsv join --left-anti positionid $EXTD_21 position wikidata/legislative-positions.csv |
  qsv select positionid,position,person,personID,start,end,gender,DOB,DOD,image,enwiki | uniq > $TMPFILE
qsv select \!positionid $TMPFILE > html/holders21.csv

# no end-date, and in wanted-positions => current.csv
qsv join positionid $TMPFILE position wikidata/wanted-positions.csv |
  qsv search -s end -v . |
  qsv select position,person,personID,start,gender,DOB,DOD,image,enwiki | uniq > html/current.csv

# Generate stats
count_leaders=$(qsv select personID html/current.csv | qsv dedup | qsv search Q | qsv count)
count_historc=$(qsv select personID html/holders21.csv | qsv dedup | qsv search Q | qsv count)
count_legislt=$(qsv select personID html/legislators.csv | qsv dedup | qsv search Q | qsv count)
count_uniqppl=$((for f in html/[chl]*.csv; do qsv select personID $f; done) | qsv sort | qsv dedup | qsv search Q | qsv count)
echo $count_leaders,$count_historc,$count_legislt,$count_uniqppl | tr -d ' ' | qsv rename -n "leaders,historic,legislators,unique" > html/stats.csv

# Generate HTML
erb country="$(jq -r .jurisdiction.name meta.json)" csvfile=html/current.csv -r csv -T- pcb/index.erb > html/index.html

# Tests

IFS=$'\n'

warnings=($(qsv join --left-anti title wikidata/wanted-positions.csv position html/current.csv | qsv join position - id html/positions.csv | qsv search -s end -v . | qsv select position,title | qsv behead))
if [ ${#warnings[@]} -gt 0 ]; then
  echo "## No current holders for:"
  printf '* %s\n' "${warnings[@]}"
fi

warnings=($(qsv join --left-anti title wikidata/wanted-positions.csv position html/holders21.csv | qsv behead))
if [ ${#warnings[@]} -gt 0 ]; then
  echo "## No knowns holders for:"
  printf '* %s\n' "${warnings[@]}"
fi

warnings=($(qsv search -s DOD . html/current.csv | qsv behead))
if [ ${#warnings[@]} -gt 0 ]; then
  echo "## Dead, but in current.csv:"
  printf '* %s\n' "${warnings[@]}"
fi

warnings=($(qsv join --left-anti position wikidata/results/current-cabinet.csv position wikidata/wanted-positions.csv | qsv select position,positionLabel | qsv behead))
if [ ${#warnings[@]} -gt 0 ]; then
  echo "## In current-cabinet but not wanted-positions:"
  printf '* %s\n' "${warnings[@]}"
fi

warnings=($(qsv join --left-anti item wikidata/results/current-cabinet.csv personID html/current.csv | qsv select item,itemLabel,position,positionLabel | qsv behead))
if [ ${#warnings[@]} -gt 0 ]; then
  echo "## In data/wikidata but not current.csv:"
  printf '* %s\n' "${warnings[@]}"
fi

warnings=($(qsv frequency -s position html/current.csv -l 0 | qsv search -s count -v '^1$' | qsv select value,count | qsv table | qsv behead))
if [ ${#warnings[@]} -gt 0 ]; then
  echo "## Multiple holders:"
  printf '* %s\n' "${warnings[@]}"
fi

warnings=($(qsv search -s dobp -v 11 $BIO_CSV | qsv join id - personID html/current.csv | qsv join position - title $ENUM_PS | qsv sort -N -s index | qsv select id,name,dob,dobp,position | uniq | qsv behead | qsv table))
if [ ${#warnings[@]} -gt 0 ]; then
  echo "## Missing/short DOB:"
  printf '* %s\n' "${warnings[@]}"
fi

warnings=($(qsv search -s gender -v male html/current.csv | qsv select 1-3 | qsv behead))
if [ ${#warnings[@]} -gt 0 ]; then
  echo "## Missing gender:"
  printf '* %s\n' "${warnings[@]}"
fi

warnings=($(qsv join --left-anti prev $EXTD_21 id $BIO_CSV | qsv search -s start "^2" | qsv search -s prev . | qsv select prev,position,start,personID | qsv sort -s start -R | uniq | qsv behead | qsv table | head -30))
if [ ${#warnings[@]} -gt 0 ]; then
  echo "## Missing predecessors:"
  echo '```'
  printf '%s\n' "${warnings[@]}"
  echo '```'
fi

warnings=($(qsv join --left-anti next $EXTD_21 id $BIO_CSV | qsv search -s next . | qsv select next,position,end,personID | qsv sort -s end -R | uniq | qsv behead | qsv table | head -30))
if [ ${#warnings[@]} -gt 0 ]; then
  echo "## Missing successors:"
  echo '```'
  printf '%s\n' "${warnings[@]}"
  echo '```'
fi

warnings=($(qsv join --left-anti person $UNDATED  id $BIO_CSV | qsv join position $ENUM_PS position - | qsv sort -R -s birth | qsv sort -N -s index | qsv select title,person,personLabel,birth,death | qsv behead | qsv table))
if [ ${#warnings[@]} -gt 0 ]; then
  echo "## Undated:"
  echo '```'
  printf '%s\n' "${warnings[@]}"
  echo '```'
fi

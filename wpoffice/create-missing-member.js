// qsv search -s item -v Q diff.csv | qsv search -s @@ '\+\+' | qsv select itemlabel,startdate,enddate | qsv behead | qsv fmt -t " "   | wd ce create-missing-member.js --batch

const fs = require('fs');
let rawmeta = fs.readFileSync('meta.json');
let meta = JSON.parse(rawmeta);

module.exports = (label, startdate, enddate) => {
  qualifier = {
    P580: startdate,
    P582: enddate || null,
  }

  mem = {
    value: meta.position,
    qualifiers: qualifier,
    references: {
      P4656: meta.source,
      P813:  new Date().toISOString().split('T')[0],
      P1810: label,
    }
  }

  claims = {
    P31: { value: 'Q5' }, // human
    P106: { value: 'Q82955' }, // politician
    P39: mem,
  }

  return {
    type: 'item',
    labels: { en: label },
    descriptions: { en: 'politician in South Sudan' },
    claims: claims,
  }
}

// qsv search -s item Q diff.csv | qsv search -s @@ '\+\+' | qsv select item,itemlabel,startdate,enddate | qsv behead | qsv fmt -t " "  | wd ee add-p39.js --batch

const fs = require('fs');
let rawmeta = fs.readFileSync('meta.json');
let meta = JSON.parse(rawmeta);

module.exports = (id, position, startdate, enddate) => {
  qualifier = {
    P580: startdate || meta.cabinet.start,
    P582: enddate   || meta.cabinet.end,
  }

  refs = { }

  if(process.env.REF) {
    var wpref = /wikipedia.org/;
    if (wpref.test(process.env.REF)) {
      refs['P4656'] = process.env.REF
    } else {
      refs['P854'] = process.env.REF
    }
  }

  if(startdate) qualifier['P580']  = startdate
  if(enddate)   qualifier['P582']  = enddate

  return {
    id,
    claims: {
      P39: {
        value: position,
        qualifiers: qualifier,
        references: refs
      }
    }
  }
}

import fs from 'node:fs/promises';
import { FileBlob, SpreadsheetFile } from '@oai/artifact-tool';

const root=process.cwd();
const inputPath=`${root}/outputs/01a0ad73-194e-7ae1-80b9-53f5d187c8cd/terapin-wow-professions-by-profession.xlsx`;
const outPath=`${root}/outputs/01a0ad73-194e-7ae1-80b9-53f5d187c8cd/terapin-wow-professions-by-profession-content-type.xlsx`;
const professions=['Blacksmithing','Leatherworking','Tailoring','Alchemy','Enchanting','Engineering','Jewelcrafting','Mining','Herbalism','Skinning','Cooking','First Aid','Fishing','Survivalist'];
const navy='#17365D', blue='#D9EAF7', ink='#1F2937', muted='#666666';
function contentType(craftSpellId,itemId){const s=Number(craftSpellId)||0,i=Number(itemId)||0;return (i>=90000||(s>=38000&&s<60000))?'Custom':'Vanilla';}
function col(n){let s='';while(n){let r=(n-1)%26;s=String.fromCharCode(65+r)+s;n=Math.floor((n-1)/26);}return s;}
const wb=await SpreadsheetFile.importXlsx(await FileBlob.load(inputPath));

// Add the column to the original combined view at the end, preserving its table.
const craft=wb.worksheets.getItem('Craftables');
craft.getRange('P4').values=[['Content Type']]; craft.getRange('P4').format={fill:navy,font:{name:'Arial',size:10,bold:true,color:'#FFFFFF'},horizontalAlignment:'center',verticalAlignment:'center',wrapText:true,borders:{preset:'all',style:'thin',color:'#FFFFFF'}};
const craftValues=craft.getRange('A5:O442').values||[]; const craftContent=craftValues.map(r=>[contentType(r[13],r[14])]);
craft.getRange('P5:P442').values=craftContent; craft.getRange('P5:P442').format={font:{name:'Arial',size:10,bold:true,color:ink},verticalAlignment:'center',wrapText:true}; craft.getRange('P:P').format.columnWidth=15;
craft.getRange('P5:P442').conditionalFormats.add('containsText',{text:'Custom',format:{fill:'#FCE4D6',font:{color:'#9C0006',bold:true}}}); craft.getRange('P5:P442').conditionalFormats.add('containsText',{text:'Vanilla',format:{fill:'#E2F0D9',font:{color:'#006100',bold:true}}});

for(const p of professions){
  const sh=wb.worksheets.getItem(p); const used=sh.getUsedRange(true); const all=used.values||[]; const data=all.slice(4).filter(r=>r&&r[1]);
  const baseHeaders=(all[3]||[]).slice(0,32); const headers=[...baseHeaders.slice(0,2),'Content Type',...baseHeaders.slice(2)]; const rows=data.map(r=>[...r.slice(0,2),contentType(r[2],r[3]),...r.slice(2)]);
  for(const t of (sh.tables.items||[])) t.delete();
  sh.getRange('A1:AG1000').clear({applyTo:'all'});
  const endCol=col(headers.length), endRow=4+Math.max(rows.length,1);
  sh.getRange(`A1:${endCol}1`).merge(); sh.getRange(`A1:${endCol}1`).values=[[`${p} — vanilla Turtle WoW craftables`]]; sh.getRange(`A1:${endCol}1`).format={font:{name:'Arial',size:14,bold:true,color:navy},verticalAlignment:'center'};
  sh.getRange(`A2:${endCol}2`).merge(); sh.getRange(`A2:${endCol}2`).values=[[rows.length?`${rows.length} rows from the supplied workbook. Content Type is inferred from the item and craft-spell IDs.`:'No rows for this profession are present in the supplied workbook.']]; sh.getRange(`A2:${endCol}2`).format={font:{name:'Arial',size:10,italic:true,color:muted},wrapText:true};
  sh.getRange(`A4:${endCol}4`).values=[headers]; sh.getRange(`A4:${endCol}4`).format={fill:navy,font:{name:'Arial',size:10,bold:true,color:'#FFFFFF'},horizontalAlignment:'center',verticalAlignment:'center',wrapText:true,borders:{preset:'all',style:'thin',color:'#FFFFFF'}};
  if(rows.length){sh.getRange(`A5:${endCol}${4+rows.length}`).values=rows; sh.getRange(`A5:${endCol}${4+rows.length}`).format={font:{name:'Arial',size:10,color:ink},verticalAlignment:'center',wrapText:true,borders:{insideHorizontal:{style:'thin',color:'#D9E2F3'}}}; sh.tables.add(`A4:${endCol}${4+rows.length}`,true,`${p.replace(/[^A-Za-z]/g,'')}ContentTable`);}
  sh.getRange(`A5:A${endRow}`).format.font={name:'Arial',bold:true,color:navy}; sh.getRange(`B5:B${endRow}`).format.font={name:'Arial',bold:true,color:ink}; sh.getRange(`C5:C${endRow}`).format.font={name:'Arial',bold:true,color:ink};
  sh.getRange(`C5:C${endRow}`).conditionalFormats.add('containsText',{text:'Custom',format:{fill:'#FCE4D6',font:{color:'#9C0006',bold:true}}}); sh.getRange(`C5:C${endRow}`).conditionalFormats.add('containsText',{text:'Vanilla',format:{fill:'#E2F0D9',font:{color:'#006100',bold:true}}});
  sh.freezePanes.freezeRows(4); sh.freezePanes.freezeColumns(2);
  const widths=[10,28,15,14,10,11,12,13,14,12,16,11,18,12,34,10,10,10,10,11,25,12,11,25,12,11,25,12,11,25,12,35]; widths.splice(2,0,15); widths.forEach((w,i)=>sh.getRangeByIndexes(0,i,1,1).format.columnWidth=w);
  sh.getRange(`A1:${endCol}1`).format.rowHeight=26; sh.getRange(`A2:${endCol}2`).format.rowHeight=24; sh.getRange(`A4:${endCol}4`).format.rowHeight=38;
}

const source=wb.worksheets.getItem('Sources & Notes'); source.getRange('A14:B17').values=[['Content Type rule','Custom when Item ID is 90000+ or Craft Spell ID is 38000–59999; otherwise Vanilla.'],['Why this rule','These are the reserved custom ID ranges used by the Terapin content in the supplied workbook.'],['Review note','If you add Turtle-specific records with different IDs, update this rule or override the label manually.'],['No inference','The workbook does not infer custom status from item names or stats.']]; source.getRange('A14:B17').format={font:{name:'Arial',size:10,color:ink},verticalAlignment:'top',wrapText:true}; source.getRange('A14:A17').format.font={name:'Arial',bold:true,color:navy};
wb.recalculate();
const check=await wb.inspect({kind:'table',sheetId:'Blacksmithing',range:'A4:AG10',include:'values,formulas',tableMaxRows:7,tableMaxCols:33}); console.log(check.ndjson);
const errors=await wb.inspect({kind:'match',searchTerm:'#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A|#NUM!|#NULL!|#SPILL!|#CALC!',options:{useRegex:true,maxResults:100},summary:'content type formula error scan'}); console.log(errors.ndjson);
await fs.mkdir(`${root}/outputs/01a0ad73-194e-7ae1-80b9-53f5d187c8cd`,{recursive:true}); const x=await SpreadsheetFile.exportXlsx(wb); await x.save(outPath); console.log(outPath);

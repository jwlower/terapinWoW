import fs from 'node:fs/promises';
import { FileBlob, SpreadsheetFile } from '@oai/artifact-tool';

const root = process.cwd();
const inputPath = `${root}/wiki/terapin-wow-professions.xlsx`;
const outDir = `${root}/outputs/01a0ad73-194e-7ae1-80b9-53f5d187c8cd`;
const input = await FileBlob.load(inputPath);
const wb = await SpreadsheetFile.importXlsx(input);
const info = await wb.inspect({kind:'workbook,sheet,table',maxChars:8000,tableMaxRows:5,tableMaxCols:8});
console.log(info.ndjson);

const craft = wb.worksheets.getItem('Craftables');
const coverage = wb.worksheets.getItem('Profession Coverage');
let sources = wb.worksheets.getItemOrNullObject?.('Sources & Notes');
if (!sources || sources.isNullObject) sources = wb.worksheets.add('Sources & Notes');

const navy='#17365D', blue='#D9EAF7', pale='#F5F8FB', ink='#1F2937', muted='#666666', amber='#FCE4D6', green='#E2F0D9';
for(const s of [craft,coverage,sources]){s.showGridLines=false;}

// Restyle the main craftable table without changing its values.
craft.getRange('A1:O2').format.font={name:'Aptos',color:ink};
craft.getRange('A1:O1').format={font:{name:'Aptos',size:16,bold:true,color:navy},verticalAlignment:'center'};
craft.getRange('A2:O2').format={font:{name:'Aptos',size:10,italic:true,color:muted},wrapText:true};
craft.getRange('A4:O4').format={fill:navy,font:{name:'Aptos',size:10,bold:true,color:'#FFFFFF'},horizontalAlignment:'center',verticalAlignment:'center',wrapText:true,borders:{preset:'all',style:'thin',color:'#FFFFFF'}};
const used=craft.getUsedRange(true); const endRow=used.rowCount||used.getRowCount?.()||1000; const last=Math.max(5,endRow);
craft.getRange(`A5:O${last}`).format={font:{name:'Aptos',size:10,color:ink},verticalAlignment:'center',wrapText:true,borders:{insideHorizontal:{style:'thin',color:'#D9E2F3'}}};
craft.getRange(`C5:G${last}`).format.numberFormat='0'; craft.getRange(`L5:O${last}`).format.numberFormat='0';
craft.getRange(`D5:D${last}`).conditionalFormats.add('cellIs',{operator:'equal',formula:'=D5',format:{fill:amber,font:{color:'#9C0006'}}});
craft.getRange(`F5:F${last}`).conditionalFormats.add('cellIs',{operator:'equal',formula:'=F5',format:{fill:green,font:{color:'#006100'}}});
craft.getRange(`A5:A${last}`).format.font={name:'Aptos',bold:true,color:navy};
craft.getRange(`B5:B${last}`).format.font={name:'Aptos',bold:true,color:ink};
craft.freezePanes.freezeRows(4); craft.freezePanes.freezeColumns(2);
const widths=[18,30,13,10,10,10,10,44,42,18,16,11,12,14,12]; widths.forEach((w,i)=>craft.getRangeByIndexes(0,i,1,1).format.columnWidth=w);
craft.getRange('A1:O1').format.rowHeight=28; craft.getRange('A2:O2').format.rowHeight=24; craft.getRange('A4:O4').format.rowHeight=34;

// Coverage sheet: make the status view readable and keep it compact.
coverage.getRange('A1:D1').format={font:{name:'Aptos',size:16,bold:true,color:navy},verticalAlignment:'center'};
coverage.getRange('A3:D3').format={fill:navy,font:{name:'Aptos',size:10,bold:true,color:'#FFFFFF'},horizontalAlignment:'center',verticalAlignment:'center',wrapText:true,borders:{preset:'all',style:'thin',color:'#FFFFFF'}};
coverage.getRange('A4:D17').format={font:{name:'Aptos',size:10,color:ink},verticalAlignment:'center',wrapText:true,borders:{insideHorizontal:{style:'thin',color:'#D9E2F3'}}};
coverage.getRange('A4:A17').format.font={name:'Aptos',bold:true,color:navy};
coverage.getRange('B4:B17').format.numberFormat='0';
coverage.getRange('D4:D17').conditionalFormats.add('containsText',{text:'Live',format:{fill:green,font:{bold:true,color:'#006100'}}});
coverage.getRange('D4:D17').conditionalFormats.add('containsText',{text:'Not evidenced',format:{fill:'#F2F2F2',font:{color:muted}}});
[22,18,64,24].forEach((w,i)=>coverage.getRangeByIndexes(0,i,1,1).format.columnWidth=w);
coverage.getRange('A1:D1').format.rowHeight=28; coverage.getRange('A3:D3').format.rowHeight=32; coverage.getRange('A4:D17').format.rowHeight=30;
coverage.freezePanes.freezeRows(3);

// Sources tab: document the web sources without asserting that every source is perfectly synchronized.
sources.getRange('A1:C12').clear({applyTo:'contents'});
sources.getRange('A1:C1').merge();
sources.getRange('A1:C1').values=[['Online sources for vanilla Turtle WoW profession data — use these to fill or verify recipe rows; source versions can drift from the live client.']];
sources.getRange('A1:C1').format={font:{name:'Aptos',size:16,bold:true,color:navy},verticalAlignment:'center'};
sources.getRange('A3:C8').values=[
  ['Source','Use','URL'],
  ['Turtle WoW Database','Primary database for Turtle-specific items, spells, recipes, trainers, and reagent links.','https://database.turtlecraft.gg/'],
  ['Turtle WoW Database (legacy)','Older official database mirror; useful for cross-checking item and spell IDs.','https://database.turtle-wow.org/'],
  ['Turtle WoW profession changes','Official forum changelog for profession additions and changes, including custom recipes and Jewelcrafting.','https://forum.turtlecraft.gg/viewtopic.php?t=8227'],
  ['TradeSkillsData-turtle','Open-source recipe data extension with Turtle-specific recipes and sources; useful for completeness checks.','https://github.com/refaim/TradeSkillsData-turtle'],
  ['Turtle WoW profession wiki','General profession rules, rank caps, recipe colors, and profession classifications.','https://turtle-wow.fandom.com/wiki/Profession']
];
sources.getRange('A3:C3').format={fill:navy,font:{name:'Aptos',size:10,bold:true,color:'#FFFFFF'},horizontalAlignment:'center',wrapText:true};
sources.getRange('A4:C8').format={font:{name:'Aptos',size:10,color:ink},verticalAlignment:'top',wrapText:true,borders:{insideHorizontal:{style:'thin',color:'#D9E2F3'}}};
sources.getRange('A4:A8').format.font={name:'Aptos',bold:true,color:navy};
sources.getRange('A10:B12').values=[['Scope note','This workbook retains the vanilla Turtle WoW-only rows you supplied. No Terapin-added craftables are being reintroduced.'],['Verification note','Use the database as the primary record, then check the official forum changelog for Turtle-specific changes. The database may lag or contain stale trainer links, so discrepancies should be spot-checked in-game.'],['Workbook styling','Orange, yellow, green, and grey remain the skill-color columns. Filters and frozen headers are preserved.']];
sources.getRange('A10:B12').format={font:{name:'Aptos',size:10,color:ink},verticalAlignment:'top',wrapText:true};
sources.getRange('A10:A12').format.font={name:'Aptos',bold:true,color:navy};
sources.getRange('A:A').format.columnWidth=28; sources.getRange('B:B').format.columnWidth=78; sources.getRange('C:C').format.columnWidth=68;
sources.getRange('A1:C1').format.rowHeight=28; sources.getRange('A3:C3').format.rowHeight=32; sources.getRange('A4:C8').format.rowHeight=42; sources.getRange('A10:B12').format.rowHeight=36;

wb.recalculate();
const check=await wb.inspect({kind:'table',sheetId:'Craftables',range:'A4:O12',include:'values,formulas',tableMaxRows:10,tableMaxCols:15}); console.log(check.ndjson);
const errors=await wb.inspect({kind:'match',searchTerm:'#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A|#NUM!|#NULL!|#SPILL!|#CALC!',options:{useRegex:true,maxResults:100},summary:'styled workbook formula error scan'}); console.log(errors.ndjson);
await fs.mkdir(outDir,{recursive:true});
for(const [name,range] of [['Craftables','A1:O20'],['Profession Coverage','A1:D17'],['Sources & Notes','A1:C12']]){const p=await wb.render({sheetName:name,range,scale:1,format:'png'}); await fs.writeFile(`${outDir}/${name.replaceAll(' ','_')}_styled.png`,new Uint8Array(await p.arrayBuffer()));}
const output=await SpreadsheetFile.exportXlsx(wb); const outPath=`${outDir}/terapin-wow-professions-styled.xlsx`; await output.save(outPath); console.log(outPath);

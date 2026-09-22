import fs from 'node:fs/promises';
import { FileBlob, SpreadsheetFile } from '@oai/artifact-tool';

const root=process.cwd();
const inputPath=`${root}/wiki/terapin-wow-professions.xlsx`;
const outDir=`${root}/outputs/01a0ad73-194e-7ae1-80b9-53f5d187c8cd`;
const professionNames=['Blacksmithing','Leatherworking','Tailoring','Alchemy','Enchanting','Engineering','Jewelcrafting','Mining','Herbalism','Skinning','Cooking','First Aid','Fishing','Survivalist'];
const navy='#17365D', blue='#D9EAF7', ink='#1F2937', muted='#666666';
const headers=['Skill','Item Name','Craft Spell ID','Item ID','Min Level','Item Level','Quality','Item Slot','Item Type','Item Class','Item Subclass','Armor / AC','Damage','Speed','Stats & Effects','Orange','Yellow','Green','Grey','Reagent 1 Qty','Reagent 1','Reagent 1 ID','Reagent 2 Qty','Reagent 2','Reagent 2 ID','Reagent 3 Qty','Reagent 3','Reagent 3 ID','Reagent 4 Qty','Reagent 4','Reagent 4 ID','Recipe Notes'];
const input=await FileBlob.load(inputPath); const wb=await SpreadsheetFile.importXlsx(input);
const craft=wb.worksheets.getItem('Craftables');
const vals=craft.getRange('A5:O442').values||[];
function num(v){return (typeof v==='number'&&Number.isFinite(v))?v:null;}
function slot(name,type){
  const n=name.toLowerCase();
  for(const [key,val] of [['helm','Head'],['pauldrons','Shoulder'],['chest','Chest'],['bracers','Wrist'],['gauntlets','Hands'],['girdle','Waist'],['legguards','Legs'],['boots','Feet']]) if(n.includes(key)) return val;
  if((type||'').toLowerCase().includes('shield')) return 'Off Hand';
  return '';
}
function splitReagents(text){
  const out=[]; const re=/(\d+)\s*[×x]\s*(.*?)\s*\[(\d+)\]/g; let m;
  while((m=re.exec(String(text||'')))!==null) out.push([Number(m[1]),m[2].trim(),Number(m[3])]);
  return out;
}
function splitEffects(text){
  const s=String(text||''); const damage=s.match(/Damage\s+([^;]+?)(?:;|$)/i)?.[1]||''; const speed=s.match(/speed\s+([^;]+?)(?:;|$)/i)?.[1]||'';
  return {damage,speed,stats:s.replace(/Damage\s+[^;]+;?\s*/i,'').replace(/speed\s+[^;]+;?\s*/i,'').trim()};
}
const grouped=new Map(professionNames.map(p=>[p,[]]));
for(const r of vals){
  if(!r || !r[1]) continue;
  const [profession,itemName,skill,orange,yellow,green,grey,recipe,effects,minLevel,itemType,itemLevel,quality,craftSpellId,itemId]=r;
  const reagents=splitReagents(recipe); const e=splitEffects(effects); const type=String(itemType||'');
  const row=[num(skill),itemName,num(craftSpellId),num(itemId),num(minLevel),num(itemLevel),quality,slot(itemName,type),type,type.match(/armor/i)?'Armor':type.match(/weapon|shield/i)?'Weapon':'',type,'',e.damage,e.speed,e.stats,num(orange),num(yellow),num(green),num(grey)];
  for(let i=0;i<4;i++){const q=reagents[i]||['','','']; row.push(q[0],q[1],q[2]);}
  row.push(reagents.length?'':'See source row: reagent text was not machine-readable');
  const p=grouped.has(profession)?profession:'Other'; if(!grouped.has(p)) grouped.set(p,[]); grouped.get(p).push(row);
}
function col(n){let s='';while(n){let r=(n-1)%26;s=String.fromCharCode(65+r)+s;n=Math.floor((n-1)/26);}return s;}
for(const p of professionNames){
  let sh; try{sh=wb.worksheets.getItem(p);}catch{sh=wb.worksheets.add(p);}
  sh.showGridLines=false;
  const rows=(grouped.get(p)||[]).sort((a,b)=>(a[0]??999)-(b[0]??999)||String(a[1]).localeCompare(String(b[1])));
  const end=4+Math.max(rows.length,1); const endCol=col(headers.length);
  sh.getRange(`A1:${endCol}1000`).clear({applyTo:'all'});
  sh.getRange(`A1:${endCol}1`).merge(); sh.getRange(`A1:${endCol}1`).values=[[`${p} — vanilla Turtle WoW craftables`]];
  sh.getRange(`A1:${endCol}1`).format={font:{name:'Arial',size:14,bold:true,color:navy},verticalAlignment:'center'};
  sh.getRange(`A2:${endCol}2`).merge(); sh.getRange(`A2:${endCol}2`).values=[[rows.length?`${rows.length} rows from the supplied workbook. Item definitions and reagents are separated into dedicated columns.`:'No rows for this profession are present in the supplied workbook. Add verified rows from the Turtle WoW database when available.']];
  sh.getRange(`A2:${endCol}2`).format={font:{name:'Arial',size:10,italic:true,color:muted},wrapText:true};
  sh.getRange(`A4:${endCol}4`).values=[headers]; sh.getRange(`A4:${endCol}4`).format={fill:navy,font:{name:'Arial',size:10,bold:true,color:'#FFFFFF'},horizontalAlignment:'center',verticalAlignment:'center',wrapText:true,borders:{preset:'all',style:'thin',color:'#FFFFFF'}};
  if(rows.length){sh.getRange(`A5:${endCol}${4+rows.length}`).values=rows; sh.getRange(`A5:${endCol}${4+rows.length}`).format={font:{name:'Arial',size:10,color:ink},verticalAlignment:'center',wrapText:true,borders:{insideHorizontal:{style:'thin',color:'#D9E2F3'}}}; sh.tables.add(`A4:${endCol}${4+rows.length}`,true,`${p.replace(/[^A-Za-z]/g,'')}CraftablesTable`);}
  sh.getRange(`A5:A${4+Math.max(rows.length,1)}`).format.font={name:'Arial',bold:true,color:navy};
  sh.getRange(`B5:B${4+Math.max(rows.length,1)}`).format.font={name:'Arial',bold:true,color:ink};
  sh.getRange(`A5:A${4+Math.max(rows.length,1)}`).format.numberFormat='0'; sh.getRange(`C5:G${4+Math.max(rows.length,1)}`).format.numberFormat='0'; sh.getRange(`P5:S${4+Math.max(rows.length,1)}`).format.numberFormat='0'; sh.getRange(`T5:AE${4+Math.max(rows.length,1)}`).format.numberFormat='0';
  sh.freezePanes.freezeRows(4); sh.freezePanes.freezeColumns(2);
  const widths=[10,28,14,12,11,11,12,13,14,12,16,11,18,12,34,10,10,10,10,11,25,12,11,25,12,11,25,12,11,25,12,35]; widths.forEach((w,i)=>sh.getRangeByIndexes(0,i,1,1).format.columnWidth=w);
  sh.getRange(`A1:${endCol}1`).format.rowHeight=26; sh.getRange(`A2:${endCol}2`).format.rowHeight=24; sh.getRange(`A4:${endCol}4`).format.rowHeight=38;
  sh.getRange(`P5:P${4+Math.max(rows.length,1)}`).conditionalFormats.add('cellIs',{operator:'equal',formula:'=P5',format:{fill:'#FCE4D6',font:{color:'#9C0006'}}});
  sh.getRange(`R5:R${4+Math.max(rows.length,1)}`).conditionalFormats.add('cellIs',{operator:'equal',formula:'=R5',format:{fill:'#E2F0D9',font:{color:'#006100'}}});
}
wb.recalculate();
const check=await wb.inspect({kind:'table',sheetId:'Blacksmithing',range:'A4:AF12',include:'values,formulas',tableMaxRows:10,tableMaxCols:32}); console.log(check.ndjson);
const errors=await wb.inspect({kind:'match',searchTerm:'#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A|#NUM!|#NULL!|#SPILL!|#CALC!',options:{useRegex:true,maxResults:100},summary:'profession tab formula error scan'}); console.log(errors.ndjson);
await fs.mkdir(outDir,{recursive:true});
for(const p of ['Blacksmithing','Leatherworking','Tailoring']){const r=await wb.render({sheetName:p,range:'A1:AF18',scale:1,format:'png'});await fs.writeFile(`${outDir}/${p}_tab_preview.png`,new Uint8Array(await r.arrayBuffer()));}
const out=`${outDir}/terapin-wow-professions-by-profession.xlsx`; const x=await SpreadsheetFile.exportXlsx(wb); await x.save(out); console.log(JSON.stringify({out,counts:Object.fromEntries([...grouped].map(([k,v])=>[k,v.length]))}));

import fs from 'node:fs/promises';
import { SpreadsheetFile, Workbook } from '@oai/artifact-tool';

const root = process.cwd();
const outDir = `${root}/outputs/01a0ad73-194e-7ae1-80b9-53f5d187c8cd`;
const files = [
  'db/3-content/05-craftable-shield.sql',
  'db/3-content/15-shields.sql',
  'db/3-content/27-white-weapons.sql',
  'db/3-content/07-weapons.sql',
  'db/3-content/33-craftable-gear.sql',
];
const professionNames = ['Blacksmithing','Leatherworking','Tailoring','Alchemy','Enchanting','Engineering','Jewelcrafting','Mining','Herbalism','Skinning','Cooking','First Aid','Fishing','Survivalist'];
const reagentNames = {
  2318:'Light Leather', 2319:'Medium Leather', 4234:'Heavy Leather', 4304:'Thick Leather', 8170:'Rugged Leather', 8171:'Rugged Leather (special)',
  2840:'Copper Bar', 2841:'Bronze Bar', 3575:'Iron Bar', 3859:'Steel Bar', 3860:'Mithril Bar', 12359:'Thorium Bar',
  7067:'Elemental Air', 42149:'Bundle of Simple Sticks', 42150:'Bundle of Seasoned Sticks', 42151:'Bundle of Ironwood Sticks', 42152:'Bundle of Starwood Sticks', 42153:'Bundle of Star Wood Sticks'
};
const statNames = {3:'Agility',4:'Strength',5:'Intellect',6:'Spirit',7:'Stamina'};
const qualityNames = {0:'Poor',1:'Common',2:'Uncommon',3:'Rare',4:'Epic',5:'Legendary'};

function num(re, s, d=null) { const m=s.match(re); return m ? Number(m[1]) : d; }
function str(re, s, d='') { const m=s.match(re); return m ? m[1] : d; }
function parseAssign(block, field) { return num(new RegExp(`\\b${field}\\s*=\\s*(\\d+)`), block, 0); }
function clean(s) { return s.replace(/\r/g,'').replace(/\s+/g,' ').trim(); }
function parseSql(text, source) {
  const items = new Map();
  const itemRe = /UPDATE tmp_(?:i|s|g|w) SET[\s\S]{0,40}?entry\s*=\s*(\d+),([\s\S]*?)INSERT INTO item_template SELECT \* FROM tmp_/g;
  for (const m of text.matchAll(itemRe)) {
    const b=m[2], id=Number(m[1]);
    const name=str(/\bname\s*=\s*'([^']+)'/,b,'');
    if (!name) continue;
    const stats=[];
    for (let i=1;i<=5;i++) { const t=parseAssign(b,`stat_type${i}`), v=parseAssign(b,`stat_value${i}`); if(t&&v) stats.push(`${statNames[t]||`Stat ${t}`} +${v}`); }
    const dmgMin=num(/\bdmg_min1\s*=\s*([0-9.]+)/,b), dmgMax=num(/\bdmg_max1\s*=\s*([0-9.]+)/,b), delay=num(/\bdelay\s*=\s*(\d+)/,b);
    const effect = stats.length ? stats.join('; ') : (dmgMin!==null ? `Damage ${dmgMin}–${dmgMax}; speed ${(delay/1000).toFixed(2)} sec` : 'No stats or on-use effects');
    items.set(id,{id,name,requiredLevel:num(/\brequired_level\s*=\s*(\d+)/,b),itemLevel:num(/\bitem_level\s*=\s*(\d+)/,b),quality:qualityNames[parseAssign(b,'Quality')]||'',type: source.includes('27-white') ? 'Weapon' : source.includes('33-craftable') ? 'Armor' : 'Shield',effects:effect,armor:num(/\barmor\s*=\s*(\d+)/,b),source});
  }
  const recipes=[];
  const craftRe=/UPDATE tmp_c SET[\s\S]{0,40}?entry\s*=\s*(\d+),[\s\S]{0,40}?name\s*=\s*'([^']+)'([\s\S]*?)INSERT INTO spell_template SELECT \* FROM tmp_c;/g;
  for (const m of text.matchAll(craftRe)) {
    const spellId=Number(m[1]), name=m[2], b=m[3];
    const itemId=num(/effectItemType1\s*=\s*(\d+)/,b);
    if(!itemId) continue;
    const reagents=[];
    for (let i=1;i<=4;i++){ const id=num(new RegExp(`reagent${i}\\s*=\\s*(\\d+)`),b,0), cnt=num(new RegExp(`reagent${i}\\s*=\\s*\\d+,\\s*reagentCount${i}\\s*=\\s*(\\d+)`),b,0); if(id&&cnt) reagents.push(`${cnt} × ${reagentNames[id]||`Item ${id}`} [${id}]`); }
    const after=text.slice(m.index+m[0].length, m.index+m[0].length+2000);
    const skillM=after.match(new RegExp(`VALUES\\s*\\(\\s*\\d+\\s*,\\s*(\\d+)\\s*,\\s*${spellId}\\s*,\\s*(\\d+)\\s*,\\s*(\\d+)\\s*,\\s*(\\d+)`));
    const skill=skillM?Number(skillM[2]):null, grey=skillM?Number(skillM[3]):null, green=skillM?Number(skillM[4]):null;
    const profession = skillM ? ({164:'Blacksmithing',165:'Leatherworking',197:'Tailoring'}[Number(skillM[1])] || 'Other') : 'Blacksmithing';
    recipes.push({profession,spellId,name,itemId,reagents:reagents.join('; '),skill,orange:skill,yellow:skill!==null&&green!==null?Math.floor((skill+green)/2):null,green,grey,source});
  }
  return {items,recipes};
}

const allItems=new Map(), allRecipes=[];
for (const f of files) { const t=await fs.readFile(`${root}/${f}`,'utf8'); const p=parseSql(t,f); for(const [id,v] of p.items) allItems.set(id,v); allRecipes.push(...p.recipes); }
// The older Runed Copper Shield is a single custom craft whose SQL is an UPDATE rather than tmp_c.
allItems.set(90100,{id:90100,name:'Runed Copper Shield',requiredLevel:13,itemLevel:18,quality:'Uncommon',type:'Shield',effects:'Agility +3; Stamina +3',source:'db/3-content/05-craftable-shield.sql'});
allRecipes.push({profession:'Blacksmithing',spellId:38002,name:'Runed Copper Shield',itemId:90100,reagents:'Source SQL does not retain named reagent fields in the custom update',skill:25,orange:25,yellow:40,green:55,grey:65,source:'db/3-content/05-craftable-shield.sql'});
const rows=[];
for(const r of allRecipes){ const it=allItems.get(r.itemId)||{id:r.itemId,name:r.name,requiredLevel:null,itemLevel:null,quality:'',type:'Craftable',effects:'Not present in source SQL'}; rows.push([r.profession||'Blacksmithing',it.name,r.skill,r.orange,r.yellow,r.green,r.grey,r.reagents||'No reagents recorded',it.effects,it.requiredLevel,it.type,it.itemLevel,it.quality,r.spellId,it.id]); }
rows.sort((a,b)=>(a[2]??999)-(b[2]??999)||a[1].localeCompare(b[1]));
const coverage=professionNames.map(p=>{const n=rows.filter(r=>r[0]===p).length; return [p,n,n?'Custom recipes in repository':'No custom recipes in repository; stock DB not included',n?'Live':'Not evidenced by repository source'];});

const wb=Workbook.create();
const detail=wb.worksheets.add('Craftables'); const cov=wb.worksheets.add('Profession Coverage'); const src=wb.worksheets.add('Sources & Notes');
for(const s of [detail,cov,src]){s.showGridLines=false; s.getRange('A1:Z2000').format.font={name:'Arial',size:10,color:'#1F2937'};}
detail.getRange('A1:O1').merge(); detail.getRange('A1').values=[['Terapin WoW craftables — repository-backed catalog']]; detail.getRange('A1').format={font:{name:'Arial',size:14,bold:true,color:'#17365D'}};
detail.getRange('A2:O2').merge(); detail.getRange('A2').values=[[`Turtle WoW 1.12-era client; ${rows.length} custom craftables extracted from the committed SQL. Orange = learn/required skill; green = source min_value; yellow = midpoint calculation.`]]; detail.getRange('A2').format={font:{italic:true,color:'#666666'}};
const headers=['Profession','Item name','Skill to learn','Orange','Yellow','Green','Grey','Recipe / reagents','Stats and effects','Level requirements','Item types','Item level','Quality','Craft spell ID','Item ID'];
detail.getRange(`A4:O${4+rows.length}`).values=[headers,...rows];
detail.getRange('A4:O4').format={fill:'#17365D',font:{bold:true,color:'#FFFFFF'},horizontalAlignment:'center',verticalAlignment:'center',wrapText:true};
detail.getRange(`A5:O${4+rows.length}`).format={verticalAlignment:'center',wrapText:true};
detail.getRange(`C5:G${4+rows.length}`).format.numberFormat='0'; detail.getRange(`L5:O${4+rows.length}`).format.numberFormat='0';
detail.tables.add(`A4:O${4+rows.length}`,true,'CraftablesTable'); detail.freezePanes.freezeRows(4); detail.freezePanes.freezeColumns(2);
detail.getRange(`D5:D${4+rows.length}`).conditionalFormats.add('cellIs',{operator:'equal',formula:'=D5',format:{fill:'#F4CCCC'}});
detail.getRange(`F5:F${4+rows.length}`).conditionalFormats.add('cellIs',{operator:'equal',formula:'=F5',format:{fill:'#D9EAD3'}});
const widths=[16,28,12,10,10,10,10,42,38,16,16,11,12,14,12]; widths.forEach((w,i)=>detail.getRangeByIndexes(0,i,1,1).format.columnWidth=w);
cov.getRange('A1:D1').merge(); cov.getRange('A1').values=[['Profession coverage in the Terapin WoW repository']]; cov.getRange('A1').format={font:{name:'Arial',size:14,bold:true,color:'#17365D'}};
cov.getRange('A3:D17').values=[['Profession','Custom craftable rows','Evidence scope','Status'],...coverage]; cov.getRange('A3:D3').format={fill:'#17365D',font:{bold:true,color:'#FFFFFF'},horizontalAlignment:'center'}; cov.getRange('A4:D17').format={wrapText:true,verticalAlignment:'center'}; cov.tables.add('A3:D17',true,'ProfessionCoverageTable'); cov.freezePanes.freezeRows(3); [20,18,58,18].forEach((w,i)=>cov.getRangeByIndexes(0,i,1,1).format.columnWidth=w);
src.getRange('A1:F1').merge(); src.getRange('A1').values=[['Sources, definitions, and limitations']]; src.getRange('A1').format={font:{name:'Arial',size:14,bold:true,color:'#17365D'}};
src.getRange('A3:B10').values=[['Topic','Notes'],['Version','Terapin WoW, private vanilla 1.12 server built on a VMangos-derived core; Turtle WoW 1.12-era client.'],['Primary source','Committed SQL migrations in db/3-content/05-craftable-shield.sql, 15-shields.sql, 27-white-weapons.sql, and 33-craftable-gear.sql.'],['Coverage','The workbook includes custom craftables shipped by this repository. The full stock world database is not committed, so stock craftables for other professions are not asserted here.'],['Profession list','Includes Blacksmithing, Leatherworking, Tailoring, Alchemy, Enchanting, Engineering, Jewelcrafting, Mining, Herbalism, Skinning, Cooking, First Aid, Fishing, and Survivalist.'],['Skill colors','Orange is req_skill_value. Green is min_value. Grey is max_value. Yellow is calculated as floor((orange + green) / 2), matching the standard midpoint convention for this source schema.'],['Recipe field','Reagents retain source item IDs when a reagent name is not available in the repository.'],['Counts','Repository docs state 166 custom Blacksmithing recipes and 272 craftable gear pieces; rows are sourced from the recipe SQL blocks.']]; src.getRange('A3:B3').format={fill:'#17365D',font:{bold:true,color:'#FFFFFF'}}; src.getRange('A4:B10').format={wrapText:true,verticalAlignment:'top'}; src.getRange('A:A').format.columnWidth=22; src.getRange('B:B').format.columnWidth=105;
wb.recalculate();
const check=await wb.inspect({kind:'table',sheetId:'Craftables',range:`A4:O12`,include:'values,formulas',tableMaxRows:10,tableMaxCols:15}); console.log(check.ndjson);
const errors=await wb.inspect({kind:'match',searchTerm:'#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A|#NUM!|#NULL!|#SPILL!|#CALC!',options:{useRegex:true,maxResults:50},summary:'final formula error scan'}); console.log(errors.ndjson);
await fs.mkdir(outDir,{recursive:true});
for(const [name,range] of [['Craftables',`A1:O20`],['Profession Coverage','A1:D17'],['Sources & Notes','A1:B10']]){const p=await wb.render({sheetName:name,range,scale:1,format:'png'}); await fs.writeFile(`${outDir}/${name.replaceAll(' ','_')}.png`,new Uint8Array(await p.arrayBuffer()));}
const xlsx=await SpreadsheetFile.exportXlsx(wb); await xlsx.save(`${outDir}/terapin-wow-professions.xlsx`);
console.log(JSON.stringify({rows:rows.length,recipes:allRecipes.length,items:allItems.size,out:`${outDir}/terapin-wow-professions.xlsx`}));

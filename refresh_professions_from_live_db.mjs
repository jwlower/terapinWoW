import fs from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { FileBlob, SpreadsheetFile } from '@oai/artifact-tool';

const root=process.cwd();
const mysql='D:/Games/turtlewow/TortoiseNew/TortoiseCompiledNew/DB/bin/mysql.exe';
const input=`${root}/outputs/01a0ad73-194e-7ae1-80b9-53f5d187c8cd/terapin-wow-professions-by-profession-content-type.xlsx`;
const output=`${root}/outputs/01a0ad73-194e-7ae1-80b9-53f5d187c8cd/terapin-wow-professions-live-db-corrected-skills-with-item-descriptions.xlsx`;
const referenceInput=`${root}/outputs/01a0ad73-194e-7ae1-80b9-53f5d187c8cd/terapin-wow-professions-live-db-corrected-skills.xlsx`;
const outDir=`${root}/outputs/01a0ad73-194e-7ae1-80b9-53f5d187c8cd`;
const professions={129:'First Aid',142:'Survivalist',164:'Blacksmithing',165:'Leatherworking',171:'Alchemy',182:'Herbalism',185:'Cooking',186:'Mining',197:'Tailoring',202:'Engineering',333:'Enchanting',356:'Fishing',393:'Skinning',755:'Jewelcrafting'};
const professionList=Object.values(professions);
const headers=['Content Type','Skill to Learn','Orange','Yellow','Green','Grey','Recipe / Spell Name','Result Item Name','Craft Spell ID','Result Item ID','Min Level','Item Level','Quality','Item Slot','Item Class','Item Subclass','Armor / AC','Damage','Speed','Stats & Effects','Item Description / Use','Reagent 1 Qty','Reagent 1','Reagent 1 ID','Reagent 2 Qty','Reagent 2','Reagent 2 ID','Reagent 3 Qty','Reagent 3','Reagent 3 ID','Reagent 4 Qty','Reagent 4','Reagent 4 ID','Recipe Description','Data Source'];
const navy='#17365D', ink='#1F2937', muted='#666666';
const inv={0:'None',1:'Head',2:'Neck',3:'Shoulder',4:'Shirt',5:'Chest',6:'Waist',7:'Legs',8:'Feet',9:'Wrist',10:'Hands',11:'Finger',12:'Trinket',13:'One-Hand',14:'Shield',15:'Ranged',16:'Back',17:'Two-Hand',18:'Bag',19:'Tabard',20:'Robe',21:'Main Hand',22:'Off Hand',23:'Holdable',24:'Ammo',25:'Thrown',26:'Ranged Right',28:'Relic'};
const cls={0:'Consumable',1:'Container',2:'Weapon',3:'Gem',4:'Armor',5:'Reagent',6:'Projectile',7:'Trade Goods',9:'Recipe',11:'Quiver',12:'Quest',13:'Key',15:'Misc'};
const sub={2:{0:'Axe',1:'One-Hand Axe',2:'Two-Hand Axe',3:'Bow',4:'Gun',5:'Mace',6:'One-Hand Mace',7:'Two-Hand Mace',8:'Polearm',9:'Sword',10:'One-Hand Sword',11:'Two-Hand Sword',13:'Fist Weapon',15:'Dagger',16:'Thrown',17:'Spear',18:'Crossbow',19:'Wand',20:'Fishing Pole'},4:{0:'Misc',1:'Cloth',2:'Leather',3:'Mail',4:'Plate',5:'Buckler',6:'Shield',7:'Libram',8:'Idol',9:'Totem',10:'Sigil'},9:{0:'Book',1:'Leatherworking',2:'Tailoring',3:'Engineering',4:'Blacksmithing',5:'Cooking',6:'Alchemy',7:'First Aid',8:'Enchanting',9:'Fishing',10:'Jewelcrafting'}};
const stat={1:'Mana',2:'Health',3:'Agility',4:'Strength',5:'Intellect',6:'Spirit',7:'Stamina',12:'Defense',13:'Dodge',14:'Parry',15:'Block',16:'Hit',17:'Crit',18:'Hit Spell',19:'Crit Spell',20:'Haste',21:'Resilience'};
function q(sql){return execFileSync(mysql,['--skip-ssl','--protocol=TCP','-h','127.0.0.1','-P','3307','-u','root','-N','-B','-e',sql],{encoding:'utf8',maxBuffer:256*1024*1024}).trim();}
function escSql(s){return String(s).replace(/\\t/g,' ').replace(/\\r/g,' ').replace(/\\n/g,' ');}
function n(v){return v===''||v===undefined||v===null||v==='NULL'?null:Number(v);}
function content(spell,item){return (Number(item)>=90000||(Number(spell)>=38000&&Number(spell)<60000))?'Custom':'Vanilla';}
function parseStats(a){const out=[];for(let i=0;i<5;i++){const t=n(a[i*2]),v=n(a[i*2+1]);if(t&&v)out.push(`${stat[t]||`Stat ${t}`} ${v>0?'+':''}${v}`);}return out.join('; ');}
function col(x){let s='';while(x){const r=(x-1)%26;s=String.fromCharCode(65+r)+s;x=Math.floor((x-1)/26);}return s;}
const sql=`SELECT sla.skill_id,s.entry,s.name,sla.req_skill_value,sla.min_value,sla.max_value,
i.entry,i.name,i.Quality,i.item_level,i.required_level,i.class,i.subclass,i.inventory_type,i.armor,i.dmg_min1,i.dmg_max1,i.delay,
i.stat_type1,i.stat_value1,i.stat_type2,i.stat_value2,i.stat_type3,i.stat_value3,i.stat_type4,i.stat_value4,i.stat_type5,i.stat_value5,
REPLACE(REPLACE(REPLACE(COALESCE(i.description,''),'\\t',' '),'\\r',' '),'\\n',' '),REPLACE(REPLACE(REPLACE(COALESCE(use_spell.description,''),'\\t',' '),'\\r',' '),'\\n',' '),s.reagent1,s.reagentCount1,s.reagent2,s.reagentCount2,s.reagent3,s.reagentCount3,s.reagent4,s.reagentCount4,s.reagent5,s.reagentCount5,s.reagent6,s.reagentCount6,s.reagent7,s.reagentCount7,s.reagent8,s.reagentCount8,
REPLACE(REPLACE(REPLACE(COALESCE(s.description,''),'\\t',' '),'\\r',' '),'\\n',' '),s.effect1
FROM tw_world.spell_template s JOIN tw_world.skill_line_ability sla ON sla.spell_id=s.entry
LEFT JOIN tw_world.item_template i ON i.entry=s.effectItemType1
LEFT JOIN tw_world.spell_template use_spell ON use_spell.entry=i.spellid_1
WHERE sla.skill_id IN (129,142,164,165,171,182,185,186,197,202,333,356,393,755)
AND (s.effect1=24 OR s.effect1=53) AND (s.effect1=53 OR s.effectItemType1>0)
ORDER BY sla.skill_id,sla.req_skill_value,s.name,s.entry;`;
const lines=q(sql).split(/\r?\n/).filter(Boolean); const rows=[]; const reagentIds=new Set(); const itemIds=new Set();
for(const line of lines){const x=line.split('\t').map(v=>v==='NULL'?'':v); if(x.length<48) continue; const skillId=n(x[0]),spellId=n(x[1]),spellName=x[2],req=n(x[3]),green=n(x[4]),grey=n(x[5]),itemId=n(x[6]); if(itemId) itemIds.add(itemId); const itemName=x[7]||''; const quality=n(x[8]),ilvl=n(x[9]),minLevel=n(x[10]),itemClass=n(x[11]),itemSub=n(x[12]),invType=n(x[13]),armor=n(x[14]),dmin=n(x[15]),dmax=n(x[16]),delay=n(x[17]); const stats=parseStats(x.slice(18,28)); const itemDesc=x[28]||x[29]||''; const reag=[]; for(let j=0;j<8;j++){const id=n(x[30+j*2]),cnt=n(x[31+j*2]); if(id&&cnt){reag.push([cnt,id]);reagentIds.add(id);}} const desc=x[46]||''; const effect=n(x[47]); const yellow=req!==null&&green!==null?Math.floor((req+green)/2):null; const recipe=effect===53?`Enchant: ${spellName}`:spellName; const result=effect===53?'':itemName; const damage=dmin!==null&&dmax!==null?`${dmin}–${dmax}`:''; const speed=delay?`${(delay/1000).toFixed(2)} sec`:''; rows.push({skillId,profession:professions[skillId]||'Other',content:content(spellId,itemId),req,orange:req,yellow,green,grey,recipe,result,spellId,itemId,minLevel,ilvl,quality,slot:invType?(inv[invType]||`Inventory ${invType}`):'',itemClass:itemClass?(cls[itemClass]||`Class ${itemClass}`):'',itemSub:itemClass?(sub[itemClass]?.[itemSub]||`Subclass ${itemSub??''}`):'',armor,damage,speed,stats,itemDesc,reag,desc,source:'Live tw_world database'});}
const reagentMap={}; if(reagentIds.size){const ids=[...reagentIds].join(','); for(const line of q(`SELECT entry,REPLACE(REPLACE(REPLACE(name,'\\t',' '),'\\r',' '),'\\n',' ') FROM tw_world.item_template WHERE entry IN (${ids});`).split(/\r?\n/).filter(Boolean)){const a=line.split('\t');reagentMap[Number(a[0])]=a[1]||`Item ${a[0]}`;}}
const itemEffectMap={};
function resolveSpellText(text, base1, die1, base2, die2){
  let out=text||'';
  for(const [token,base,die] of [['$s1',base1,die1],['$s2',base2,die2]]){
    if(out.includes(token) && base!==null){ const low=Number(base)+1; const high=Number(base)+(Number(die)||1); out=out.replaceAll(token,high>low?`${low}-${high}`:String(low)); }
  }
  return out;
}
if(itemIds.size){
  const ids=[...itemIds].join(',');
  const effectSql=`SELECT i.entry,
    REPLACE(REPLACE(REPLACE(COALESCE(s1.description,''),'\\t',' '),'\\r',' '),'\\n',' '),s1.effectBasePoints1,s1.effectDieSides1,s1.effectBasePoints2,s1.effectDieSides2,
    REPLACE(REPLACE(REPLACE(COALESCE(s2.description,''),'\\t',' '),'\\r',' '),'\\n',' '),s2.effectBasePoints1,s2.effectDieSides1,s2.effectBasePoints2,s2.effectDieSides2,
    REPLACE(REPLACE(REPLACE(COALESCE(s3.description,''),'\\t',' '),'\\r',' '),'\\n',' '),s3.effectBasePoints1,s3.effectDieSides1,s3.effectBasePoints2,s3.effectDieSides2
    FROM tw_world.item_template i
    LEFT JOIN tw_world.spell_template s1 ON s1.entry=i.spellid_1
    LEFT JOIN tw_world.spell_template s2 ON s2.entry=i.spellid_2
    LEFT JOIN tw_world.spell_template s3 ON s3.entry=i.spellid_3
    WHERE i.entry IN (${ids});`;
  for(const line of q(effectSql).split(/\r?\n/).filter(Boolean)){
    const a=line.split('\t'), parts=[];
    for(let j=0;j<3;j++){ const k=1+j*5; const text=resolveSpellText(a[k],n(a[k+1]),n(a[k+2]),n(a[k+3]),n(a[k+4])); if(text) parts.push(text); }
    if(parts.length) itemEffectMap[Number(a[0])]=parts.filter((v,i,x)=>x.indexOf(v)===i).join(' | ');
  }
}
for(const row of rows){const effect=itemEffectMap[row.itemId]||''; if(effect){row.itemDesc=[row.itemDesc,effect].filter(Boolean).filter((v,i,a)=>a.indexOf(v)===i).join(' | '); row.stats=[row.stats,effect].filter(Boolean).filter((v,i,a)=>a.indexOf(v)===i).join(' | ');}}
const reference=await SpreadsheetFile.importXlsx(await FileBlob.load(referenceInput));
const referenceSkills=new Map();
for(const sheet of reference.worksheets.items){
  if(['Craftables','Profession Coverage','Sources & Notes'].includes(sheet.name)) continue;
  const values=sheet.getRange('A1:E10000').values;
  for(let i=1;i<values.length;i++){
    const skill=typeof values[i]?.[0]==='number' ? values[i][0] : values[i]?.[1];
    const name=typeof values[i]?.[0]==='number' ? values[i]?.[1] : values[i]?.[7]||values[i]?.[6];
    if(typeof skill==='number' && name) referenceSkills.set(`${sheet.name}|${String(name).trim()}`,skill);
  }
}
let referenceSkillMatches=0, derivedSkillValues=0;
for(const row of rows){
  const ref=referenceSkills.get(`${row.profession}|${String(row.result||row.recipe||'').trim()}`);
  if(ref!==undefined){ row.skillToLearn=ref; referenceSkillMatches++; }
  else if(row.req!==null && row.req>1) row.skillToLearn=row.req;
  else if(row.green!==null) { row.skillToLearn=Math.max(1,row.green-20); derivedSkillValues++; }
  else row.skillToLearn=null;
  row.orange=row.skillToLearn;
  row.yellow=row.orange!==null && row.green!==null ? Math.floor((row.orange+row.green)/2) : null;
}
const wb=await SpreadsheetFile.importXlsx(await FileBlob.load(input));
for(const p of professionList){let sh;try{sh=wb.worksheets.getItem(p);}catch{sh=wb.worksheets.add(p);} const data=rows.filter(r=>r.profession===p).sort((a,b)=>(a.skillToLearn??999)-(b.skillToLearn??999)||a.recipe.localeCompare(b.recipe)); for(const t of (sh.tables.items||[]))t.delete(); sh.getRange('A1:AI4000').clear({applyTo:'all'}); const endCol=col(headers.length), endRow=4+Math.max(data.length,1); sh.getRange(`A1:${endCol}1`).merge(); sh.getRange(`A1:${endCol}1`).values=[[`${p} — live Turtle WoW profession database`]]; sh.getRange(`A1:${endCol}1`).format={font:{name:'Arial',size:14,bold:true,color:navy},verticalAlignment:'center'}; sh.getRange(`A2:${endCol}2`).merge(); sh.getRange(`A2:${endCol}2`).values=[[`${data.length} recipe records from tw_world. Created-item recipes and Enchanting spells are included. Reagent fields are split into quantity, name, and item ID.`]]; sh.getRange(`A2:${endCol}2`).format={font:{name:'Arial',size:10,italic:true,color:muted},wrapText:true}; sh.getRange(`A4:${endCol}4`).values=[headers]; sh.getRange(`A4:${endCol}4`).format={fill:navy,font:{name:'Arial',size:10,bold:true,color:'#FFFFFF'},horizontalAlignment:'center',verticalAlignment:'center',wrapText:true,borders:{preset:'all',style:'thin',color:'#FFFFFF'}}; const matrix=data.map(r=>{const re=[];for(let j=0;j<4;j++){const z=r.reag[j];re.push(z?.[0]??null,z?reagentMap[z[1]]||`Item ${z[1]}`:'',z?.[1]??null);}return [r.content,r.skillToLearn,r.orange,r.yellow,r.green,r.grey,r.recipe,r.result,r.spellId,r.itemId,r.minLevel,r.ilvl,r.quality,r.slot,r.itemClass,r.itemSub,r.armor,r.damage,r.speed,r.stats,r.itemDesc,...re,r.desc,r.source];}); if(matrix.length){sh.getRange(`A5:${endCol}${4+matrix.length}`).values=matrix;sh.getRange(`A5:${endCol}${4+matrix.length}`).format={font:{name:'Arial',size:10,color:ink},verticalAlignment:'center',wrapText:true,borders:{insideHorizontal:{style:'thin',color:'#D9E2F3'}}};sh.tables.add(`A4:${endCol}${4+matrix.length}`,true,`${p.replace(/[^A-Za-z]/g,'')}LiveTable`);} sh.freezePanes.freezeRows(4);sh.freezePanes.freezeColumns(2); const widths=[14,12,10,10,10,10,28,28,14,12,11,11,12,15,16,20,11,14,12,34,42,11,25,12,11,25,12,11,25,12,11,25,12,36,24]; widths.forEach((w,i)=>sh.getRangeByIndexes(0,i,1,1).format.columnWidth=w); sh.getRange(`A1:${endCol}1`).format.rowHeight=26;sh.getRange(`A2:${endCol}2`).format.rowHeight=24;sh.getRange(`A4:${endCol}4`).format.rowHeight=42;sh.getRange(`A5:A${endRow}`).conditionalFormats.add('containsText',{text:'Custom',format:{fill:'#FCE4D6',font:{color:'#9C0006',bold:true}}});sh.getRange(`A5:A${endRow}`).conditionalFormats.add('containsText',{text:'Vanilla',format:{fill:'#E2F0D9',font:{color:'#006100',bold:true}}});}
// Refresh the coverage summary to reflect the live database tabs.
const cov=wb.worksheets.getItem('Profession Coverage'); cov.getRange('A4:D17').values=professionList.map(p=>{const d=rows.filter(r=>r.profession===p);return [p,d.length,'Live tw_world database','Live'];}); cov.getRange('A4:D17').format={font:{name:'Arial',size:10,color:ink},verticalAlignment:'center',wrapText:true,borders:{insideHorizontal:{style:'thin',color:'#D9E2F3'}}};
const source=wb.worksheets.getItem('Sources & Notes'); source.getRange('A19:B23').values=[['Live database source','D:\\Games\\turtlewow\\TortoiseNew\\TortoiseCompiledNew\\DB\\data\\tw_world (queried through MariaDB on 127.0.0.1:3307).'],['Recipe selection','Profession-linked spells with CREATE_ITEM (effect 24) and Enchanting spells with ENCHANT_ITEM (effect 53).'],['Skill colors','Orange=req_skill_value; green=min_value; grey=max_value; yellow is midpoint between orange and green.'],['Custom/Vanilla rule','Custom is assigned for item IDs 90000+ or craft spell IDs 38000–59999; all other records are labeled Vanilla.'],['Important','The live database is the authoritative local source for this workbook; external sites can lag behind it.']]; source.getRange('A19:B23').format={font:{name:'Arial',size:10,color:ink},verticalAlignment:'top',wrapText:true}; source.getRange('A19:A23').format.font={name:'Arial',bold:true,color:navy}; source.getRange('A:A').format.columnWidth=28;source.getRange('B:B').format.columnWidth=100;
wb.recalculate(); const check=await wb.inspect({kind:'table',sheetId:'Blacksmithing',range:'A4:AH10',include:'values,formulas',tableMaxRows:7,tableMaxCols:34}); console.log(check.ndjson); const errors=await wb.inspect({kind:'match',searchTerm:'#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A|#NUM!|#NULL!|#SPILL!|#CALC!',options:{useRegex:true,maxResults:100},summary:'live DB recipe error scan'}); console.log(errors.ndjson); await fs.mkdir(outDir,{recursive:true}); for(const p of ['Blacksmithing','Alchemy','Jewelcrafting']){const r=await wb.render({sheetName:p,range:'A1:AH18',scale:1,format:'png'});await fs.writeFile(`${outDir}/${p}_live_db_preview.png`,new Uint8Array(await r.arrayBuffer()));} const x=await SpreadsheetFile.exportXlsx(wb);await x.save(output);console.log(JSON.stringify({output,total:rows.length,counts:Object.fromEntries(professionList.map(p=>[p,rows.filter(r=>r.profession===p).length]))}));

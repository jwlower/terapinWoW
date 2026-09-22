import { FileBlob, SpreadsheetFile } from '@oai/artifact-tool';

const path='outputs/01a0ad73-194e-7ae1-80b9-53f5d187c8cd/terapin-wow-professions-live-db-corrected-skills-with-item-descriptions.xlsx';
const wb=await SpreadsheetFile.importXlsx(await FileBlob.load(path));
const source=wb.worksheets.getItem('Sources & Notes');
source.getRange('A19:B24').values=[
  ['Live database source','D:\\Games\\turtlewow\\TortoiseNew\\TortoiseCompiledNew\\DB\\data\\tw_world (queried through MariaDB on 127.0.0.1:3307).'],
  ['Recipe selection','Profession-linked spells with CREATE_ITEM (effect 24) and Enchanting spells with ENCHANT_ITEM (effect 53).'],
  ['Skill colors','Skill to Learn / Orange uses the supplied workbook when a profession and result name match. Fallback rows use req_skill_value when greater than 1, otherwise max(1, Green-20). Yellow is the midpoint between Orange and Green; Green and Grey remain live DB thresholds.'],
  ['Reference overlay','Skills were overlaid from the supplied workbook wherever profession and result name matched; remaining rows use the documented fallback.'],
  ['Custom/Vanilla rule','Custom is assigned for item IDs 90000+ or craft spell IDs 38000–59999; all other records are labeled Vanilla.'],
  ['Important','The live database is the authoritative local source for this workbook; external sites can lag behind it.']
];
source.getRange('A19:B24').format={font:{name:'Arial',size:10,color:'#1F2937'},verticalAlignment:'top',wrapText:true};
source.getRange('A19:A24').format.font={name:'Arial',bold:true,color:'#17365D'};
source.getRange('B:B').format.columnWidth=100;
source.getRange('A25:B25').values=[['Item descriptions','Item Description / Use combines the item tooltip description and the linked item-use spell description from the live database.']];
source.getRange('A25:B25').format={font:{name:'Arial',size:10,color:'#1F2937'},verticalAlignment:'top',wrapText:true};
source.getRange('A25').format.font={name:'Arial',bold:true,color:'#17365D'};
const out=await SpreadsheetFile.exportXlsx(wb); await out.save(path);
console.log(path);

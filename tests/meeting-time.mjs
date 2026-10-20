import assert from 'node:assert/strict';
import {bucharestISO,bucharestInput} from '../src/meetingTime.ts';
for(const tz of ['UTC','America/New_York','Asia/Tokyo']){process.env.TZ=tz;assert.equal(bucharestISO('2026-10-28T18:00'),'2026-10-28T16:00:00.000Z');assert.equal(bucharestISO('2026-07-28T18:00'),'2026-07-28T15:00:00.000Z');assert.throws(()=>bucharestISO('2026-03-29T03:30'));assert.equal(bucharestInput(bucharestISO('2026-10-25T03:30')),'2026-10-25T03:30');}
console.log('✓ București: iarnă, vară și schimbările orei, independent de fusul dispozitivului');

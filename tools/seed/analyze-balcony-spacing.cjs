#!/usr/bin/env node

/**
 * BALCONY SPACING ANALYSIS - Extract success metrics
 */

const fs = require('fs');
const seatmapPath = '/Users/isakparild/Desktop/thankful/public/seatmaps/hamilton_final_perfect.json';
const seatmap = JSON.parse(fs.readFileSync(seatmapPath, 'utf8'));

console.log("🔍 BALCONY SPACING ANALYSIS - THE SUCCESS TEMPLATE");
console.log("=" * 60);

// Get balcony sections
const balconySections = seatmap.sections.filter(s => s.id.includes('balcony'));
const balconySeats = seatmap.seats.filter(s => s.section_norm && s.section_norm.includes('balcony'));

console.log("\n🎭 BALCONY SECTIONS:");
balconySections.forEach(section => {
  const width = section.boundaries.endX - section.boundaries.startX;
  const height = section.boundaries.endY - section.boundaries.startY;
  console.log(`  ${section.name}:`);
  console.log(`    Boundaries: X(${section.boundaries.startX} → ${section.boundaries.endX}) Y(${section.boundaries.startY} → ${section.boundaries.endY})`);
  console.log(`    Dimensions: W=${width.toFixed(3)} H=${height.toFixed(3)}`);
  console.log(`    Seats: ${section.totalSeats} (4 rows × 6 seats)`);
});

console.log("\n🔍 INTER-SECTION SPACING ANALYSIS:");
// Calculate gaps between balcony sections
const balconyLeft = balconySections.find(s => s.id === 'balcony_left');
const balconyCenter = balconySections.find(s => s.id === 'balcony_center');
const balconyRight = balconySections.find(s => s.id === 'balcony_right');

const gap1 = balconyCenter.boundaries.startX - balconyLeft.boundaries.endX;
const gap2 = balconyRight.boundaries.startX - balconyCenter.boundaries.endX;

console.log(`  Left → Center gap: ${gap1.toFixed(4)} (${(gap1 * 100).toFixed(1)}% of screen)`);
console.log(`  Center → Right gap: ${gap2.toFixed(4)} (${(gap2 * 100).toFixed(1)}% of screen)`);
console.log(`  Average inter-section gap: ${((gap1 + gap2) / 2).toFixed(4)}`);

console.log("\n🪑 INTRA-SECTION SPACING ANALYSIS:");
// Analyze spacing within balcony sections
const leftSeats = balconySeats.filter(s => s.section_norm === 'balcony_left');
const leftRowA = leftSeats.filter(s => s.row === 'A').sort((a, b) => a.number - b.number);
const leftRowB = leftSeats.filter(s => s.row === 'B').sort((a, b) => a.number - b.number);

// Horizontal spacing (seat to seat)
const seatSpacingX = leftRowA[1].x - leftRowA[0].x;
const seatWidth = leftRowA[0].w;
const gapBetweenSeats = seatSpacingX - seatWidth;

// Vertical spacing (row to row)
const rowSpacingY = leftRowB[0].y - leftRowA[0].y;
const seatHeight = leftRowA[0].h;
const gapBetweenRows = rowSpacingY - seatHeight;

console.log(`  Seat dimensions: W=${seatWidth.toFixed(4)} H=${seatHeight.toFixed(4)}`);
console.log(`  Horizontal spacing: seat center-to-center = ${seatSpacingX.toFixed(4)}`);
console.log(`  Horizontal gap: ${gapBetweenSeats.toFixed(4)} (${(gapBetweenSeats/seatWidth*100).toFixed(1)}% of seat width)`);
console.log(`  Vertical spacing: row center-to-center = ${rowSpacingY.toFixed(4)}`);
console.log(`  Vertical gap: ${gapBetweenRows.toFixed(4)} (${(gapBetweenRows/seatHeight*100).toFixed(1)}% of seat height)`);

console.log("\n🎯 BALCONY SUCCESS METRICS:");
const leftSectionWidth = balconyLeft.boundaries.endX - balconyLeft.boundaries.startX;
const seatsPerRow = 6;
const totalSeatWidth = seatsPerRow * seatWidth;
const totalGapWidth = (seatsPerRow - 1) * gapBetweenSeats;
const usedWidth = totalSeatWidth + totalGapWidth;
const margins = leftSectionWidth - usedWidth;

console.log(`  Section efficiency: ${(usedWidth/leftSectionWidth*100).toFixed(1)}% (${usedWidth.toFixed(4)}/${leftSectionWidth.toFixed(4)})`);
console.log(`  Seat-to-gap ratio: ${(gapBetweenSeats/seatWidth).toFixed(2)}:1 horizontal, ${(gapBetweenRows/seatHeight).toFixed(2)}:1 vertical`);
console.log(`  Margins per section: ${(margins/2).toFixed(4)} on each side`);

console.log("\n🎨 VIEWPORT USAGE:");
const totalViewportWidth = 0.98; // Assume full width
const totalBalconyWidth = balconyRight.boundaries.endX - balconyLeft.boundaries.startX;
console.log(`  Balcony tier spans: ${totalBalconyWidth.toFixed(3)} (${(totalBalconyWidth/totalViewportWidth*100).toFixed(1)}% of viewport)`);
console.log(`  Left margin: ${balconyLeft.boundaries.startX.toFixed(3)} (${(balconyLeft.boundaries.startX/totalViewportWidth*100).toFixed(1)}%)`);
console.log(`  Right margin: ${(totalViewportWidth - balconyRight.boundaries.endX).toFixed(3)} (${((totalViewportWidth - balconyRight.boundaries.endX)/totalViewportWidth*100).toFixed(1)}%)`);

console.log("\n✨ SUCCESS TEMPLATE FORMULAS:");
console.log(`  Inter-section gap = ${((gap1 + gap2) / 2).toFixed(4)} (${(((gap1 + gap2) / 2) * 100).toFixed(1)}% of viewport)`);
console.log(`  Seat spacing ratio = ${(gapBetweenSeats/seatWidth).toFixed(3)} × seat_width`);
console.log(`  Row spacing ratio = ${(gapBetweenRows/seatHeight).toFixed(3)} × seat_height`);
console.log(`  Section efficiency = ${(usedWidth/leftSectionWidth*100).toFixed(1)}%`);
console.log(`  Total viewport usage = ${(totalBalconyWidth/totalViewportWidth*100).toFixed(1)}%`);

console.log("\n🎯 APPLY TO OTHER TIERS:");
console.log("  1. Use same inter-section gap ratio (9.0% of viewport)");
console.log("  2. Use same seat spacing ratios (3.36× width, 2.22× height)");  
console.log("  3. Maintain same section efficiency (~83%)");
console.log("  4. Expand viewport from 0.95 to 0.98 for more space");
console.log("  5. Scale section sizes based on seat density");

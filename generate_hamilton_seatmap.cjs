// Hamilton Victoria Palace Theater Realistic Seatmap Generator
const fs = require('fs');

const seats = [];
let seatId = 1;

// Helper function to create curved row
function createCurvedRow(rowLetter, seatCount, baseY, curvature, section, priceTier, color, category) {
  const row = [];
  const centerX = 0.5;
  const rowWidth = Math.min(0.8, seatCount * 0.025); // Max 80% width, scale with seat count
  const startX = centerX - (rowWidth / 2);
  
  for (let seatNum = 1; seatNum <= seatCount; seatNum++) {
    // Linear position along row
    const progress = (seatNum - 1) / (seatCount - 1);
    const linearX = startX + (progress * rowWidth);
    
    // Apply curvature (positive = curve toward stage)
    const curveOffset = curvature * Math.sin(Math.PI * progress) * -1; // Negative for forward curve
    const finalY = baseY + curveOffset;
    
    row.push({
      id: seatId++,
      section: section,
      row: rowLetter,
      number: seatNum,
      x: Math.round(linearX * 1000) / 1000,
      y: Math.round(finalY * 1000) / 1000,
      w: 0.02,
      h: 0.015,
      color: color,
      category: category,
      priceTier: priceTier,
      available: true
    });
  }
  return row;
}

// STALLS - Ground Floor
console.log('Generating Stalls...');

// Stalls Premium (Rows A-H) - 32 seats each, £160
const stallsPremiumRows = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
stallsPremiumRows.forEach((row, index) => {
  const baseY = 0.12 + (index * 0.025); // Start after stage, space rows
  const curvature = 0.015; // Gentle forward curve
  const rowSeats = createCurvedRow(row, 32, baseY, curvature, 'Stalls Premium', 'premium', '#8B5CF6', 'premium');
  seats.push(...rowSeats);
});

// Stalls Standard (Rows J-V) - decreasing from 30 to 26 seats, £120  
const stallsStandardRows = ['J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V'];
stallsStandardRows.forEach((row, index) => {
  const baseY = 0.32 + (index * 0.028); // Continue after premium
  const curvature = 0.020; // Slightly more curve as we go back
  const seatCount = Math.max(26, 30 - Math.floor(index / 3)); // Gradually decrease
  const rowSeats = createCurvedRow(row, seatCount, baseY, curvature, 'Stalls Standard', 'standard', '#3B82F6', 'standard');
  seats.push(...rowSeats);
});

console.log('Generating Dress Circle...');

// DRESS CIRCLE - 1st Balcony
// Dress Circle Premium (Rows A-F) - 28 seats each, £140
const dressPremiumRows = ['A', 'B', 'C', 'D', 'E', 'F'];
dressPremiumRows.forEach((row, index) => {
  const baseY = 0.55 + (index * 0.022); // Balcony level
  const curvature = 0.025; // More dramatic curve for balcony
  const rowSeats = createCurvedRow(row, 28, baseY, curvature, 'Dress Circle Premium', 'elevated_premium', '#10B981', 'elevated_premium');
  seats.push(...rowSeats);
});

// Dress Circle Standard (Rows G-M) - decreasing from 24 to 20 seats, £100
const dressStandardRows = ['G', 'H', 'I', 'J', 'K', 'L', 'M'];
dressStandardRows.forEach((row, index) => {
  const baseY = 0.68 + (index * 0.025);
  const curvature = 0.030;
  const seatCount = Math.max(20, 24 - Math.floor(index / 2));
  const rowSeats = createCurvedRow(row, seatCount, baseY, curvature, 'Dress Circle Standard', 'elevated_standard', '#F59E0B', 'elevated_standard');
  seats.push(...rowSeats);
});

console.log('Generating Upper Circle...');

// UPPER CIRCLE - 2nd Balcony
// Upper Circle (Rows A-K) - decreasing from 24 to 18 seats, £75
const upperRows = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K'];
upperRows.forEach((row, index) => {
  const baseY = 0.82 + (index * 0.015); // Steeper, more compact
  const curvature = 0.035; // Steepest curve
  const seatCount = Math.max(18, 24 - Math.floor(index / 2));
  const rowSeats = createCurvedRow(row, seatCount, baseY, curvature, 'Upper Circle', 'budget', '#EF4444', 'budget');
  seats.push(...rowSeats);
});

// Add some restricted view seats (side areas, behind pillars)
console.log('Adding restricted view seats...');
const restrictedPositions = [
  {x: 0.05, y: 0.65}, {x: 0.95, y: 0.65}, // Side dress circle
  {x: 0.08, y: 0.85}, {x: 0.92, y: 0.85}, // Side upper circle
  {x: 0.15, y: 0.95}, {x: 0.85, y: 0.95}  // Back corners
];

restrictedPositions.forEach((pos, index) => {
  seats.push({
    id: seatId++,
    section: 'Restricted View',
    row: 'RV',
    number: index + 1,
    x: pos.x,
    y: pos.y,
    w: 0.018,
    h: 0.012,
    color: '#6B7280',
    category: 'restricted',
    priceTier: 'restricted',
    available: true
  });
});

console.log(`Generated ${seats.length} seats total`);

// Read existing file and append seats
const existingContent = fs.readFileSync('/Users/isakparild/Desktop/thankful/public/seatmaps/hamilton_realistic.json', 'utf8');
const jsonData = JSON.parse(existingContent);
jsonData.seats = seats;
jsonData.total_seats = seats.length;

// Write complete file
fs.writeFileSync('/Users/isakparild/Desktop/thankful/public/seatmaps/hamilton_realistic.json', JSON.stringify(jsonData, null, 2));
console.log('Hamilton realistic seatmap generated successfully!');

const fs = require('fs');

// Read the existing realistic seatmap
const data = JSON.parse(fs.readFileSync('/Users/isakparild/Desktop/thankful/public/seatmaps/hamilton_realistic.json', 'utf8'));

// Fix the seat objects to use the expected field names
data.seats = data.seats.map(seat => ({
  ...seat,
  suggested_price_tier: seat.priceTier, // Map priceTier to suggested_price_tier
  // Keep both for compatibility
  priceTier: seat.priceTier
}));

// Add IDs to sections for parser compatibility
data.sections = data.sections.map((section, index) => ({
  ...section,
  id: section.name.toLowerCase().replace(/\s+/g, '_') // Generate consistent IDs
}));

// Write the fixed structure
fs.writeFileSync('/Users/isakparild/Desktop/thankful/public/seatmaps/hamilton_realistic.json', JSON.stringify(data, null, 2));
console.log('Fixed seatmap structure for iOS parser compatibility');

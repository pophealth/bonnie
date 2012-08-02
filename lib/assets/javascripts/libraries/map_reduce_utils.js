// Adds common utility functions to the root JS object. These are then
// available for use by the map-reduce functions for each measure.
// lib/qme/mongo_helpers.rb executes this function on a database
// connection.

var root = this;

root.map = function(record, population, denominator, numerator, exclusion, denexcep) {
  var value = {population: false, denominator: false, numerator: false, denexcep: false,
               exclusions: false, antinumerator: false, patient_id: record._id,
               medical_record_id: record.medical_record_number,
               first: record.first, last: record.last, gender: record.gender,
               birthdate: record.birthdate, test_id: record.test_id,
               provider_performances: record.provider_performances,
               race: record.race, ethnicity: record.ethnicity, languages: record.languages};
  if (population()) {
    value.population = true;
    if (denexcep()) {
      value.denexcep = true;
    } else if (denominator()) {
      value.denominator = true;
      if (numerator()) {
        value.numerator = true;
      } else if (exclusion()) {
        value.exclusions = true;
        value.denominator = false;
      } else {
        value.antinumerator = true;
      }
    }
  }

  if (typeof Logger != 'undefined') value['logger'] = Logger.logger
  
  emit(ObjectId(), value);
};

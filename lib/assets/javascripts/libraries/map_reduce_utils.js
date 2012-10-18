// Adds common utility functions to the root JS object. These are then
// available for use by the map-reduce functions for each measure.
// lib/qme/mongo_helpers.rb executes this function on a database
// connection.

var root = this;

root.map = function(record, population, denominator, numerator, exclusion, denexcep) {
  var value = {population: 0, denominator: 0, numerator: 0, denexcep: 0,
               exclusions: 0, antinumerator: 0, patient_id: record._id,
               medical_record_id: record.medical_record_number,
               first: record.first, last: record.last, gender: record.gender,
               birthdate: record.birthdate, test_id: record.test_id,
               provider_performances: record.provider_performances,
               race: record.race, ethnicity: record.ethnicity, languages: record.languages};
  var ipp = population()
  if (Specifics.validate(ipp)) {
    value.population = 1;
    if (Specifics.validate(exclusion(), ipp)) {
      value.exclusions = 1;
    } else {
      denom = denominator();
      if (Specifics.validate(denom, ipp)) {
        value.denominator = 1;
        numer = numerator()
        if (Specifics.validate(numer, denom, ipp)) {
          value.numerator = 1;
        } else { 
          excep = denexcep()
          if (Specifics.validate(excep, denom, ipp)) {
            value.denexcep = 1;
            value.denominator = 0;
          } else {
            value.antinumerator = 1;
          }
        }
      }
    }
  }


  if (typeof Logger != 'undefined') value['logger'] = Logger.logger
  
  emit(ObjectId(), value);
};

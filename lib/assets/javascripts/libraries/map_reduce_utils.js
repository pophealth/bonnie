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
  var ipp = population()
  if (Specifics.validate(ipp)) {
    value.population = true;
    if (Specifics.validate(exclusion(), ipp)) {
      value.exclusions = true;
    } else {
      denom = denominator();
      if (Specifics.validate(denom, ipp)) {
        value.denominator = true;
        numer = numerator()
        if (Specifics.validate(numer, denom, ipp)) {
          value.numerator = true;
        } else { 
          excep = denexcep()
          if (Specifics.validate(excep, denom, ipp)) {
            value.denexcep = true;
            value.denominator = false;
          } else {
            value.antinumerator = true;
          }
        }
      }
    }
  }


  if (typeof Logger != 'undefined') value['logger'] = Logger.logger
  
  emit(ObjectId(), value);
};

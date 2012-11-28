// Adds common utility functions to the root JS object. These are then
// available for use by the map-reduce functions for each measure.
// lib/qme/mongo_helpers.rb executes this function on a database
// connection.

var root = this;

root.map = function(record, population, denominator, numerator, exclusion, denexcep, occurrenceId) {
  var value = {population: 0, denominator: 0, numerator: 0, denexcep: 0,
               exclusions: 0, antinumerator: 0, patient_id: record._id,
               medical_record_id: record.medical_record_number,
               first: record.first, last: record.last, gender: record.gender,
               birthdate: record.birthdate, test_id: record.test_id,
               provider_performances: record.provider_performances,
               race: record.race, ethnicity: record.ethnicity, languages: record.languages};
  var ipp = population()
  if (hqmf.SpecificsManager.validate(ipp)) {
    value.population = hqmf.SpecificsManager.countUnique(occurrenceId, ipp);
    var exclusions = exclusion()
    if (hqmf.SpecificsManager.validate(exclusions, ipp)) {
      value.exclusions = 1;
    } else {
      var denom = denominator();
      if (hqmf.SpecificsManager.validate(denom, ipp)) {
        value.denominator = hqmf.SpecificsManager.countUnique(occurrenceId, denom, ipp);
        var numer = numerator()
        if (hqmf.SpecificsManager.validate(numer, denom, ipp)) {
          value.numerator = hqmf.SpecificsManager.countUnique(occurrenceId, numer, denom, ipp);
        } else { 
          excep = denexcep()
          if (hqmf.SpecificsManager.validate(excep, denom, ipp)) {
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

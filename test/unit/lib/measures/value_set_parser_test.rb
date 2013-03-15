require_relative '../../../test_helper'

class ValueSetParserTest < Test::Unit::TestCase
  
  def setup
    
  end
  
  def test_it_reads_an_excel_file
    file = "test/fixtures/value_sets/NQF_0043.xls"
    vsp = HQMF::ValueSet::Parser.new()
    value_sets = vsp.parse(file)

    parent_oids = ['2.16.840.1.113883.3.464.0001.49',
                   '2.16.840.1.113883.3.464.0001.143',
                   '2.16.840.1.113883.3.464.0001.430']

    child_oids = ['2.16.840.1.113883.3.560.100.4',
                  '2.16.840.1.113883.3.464.0001.48',
                  '2.16.840.1.113883.3.464.0001.50',
                  '2.16.840.1.113883.3.464.0001.139',
                  '2.16.840.1.113883.3.464.0001.140',
                  '2.16.840.1.113883.3.464.0001.141',
                  '2.16.840.1.113883.3.464.0001.142',
                  '2.16.840.1.113883.3.464.0001.97',
                  '2.16.840.1.113883.3.464.0001.429']

    vsp.parent_oids.length.must_equal parent_oids.length
    vsp.child_oids.length.must_equal child_oids.length
    (vsp.parent_oids - parent_oids).empty?.must_equal true
    (vsp.child_oids - child_oids).empty?.must_equal true
    value_sets.length.must_equal child_oids.length + parent_oids.length
    
    vs = value_sets.select {|vs| vs.oid == '2.16.840.1.113883.3.464.0001.430'}.first
    vs.display_name.must_equal "Medication Pneumococcal Vaccine All Ages"
    vs.version.must_equal "n/a"
    vs.concepts.length.must_equal 25
    vs.concepts.map(&:code_system_name).uniq.first.must_equal "RxNorm"
    vs.concepts.map(&:code).uniq.compact.length.must_equal 25

    vs = value_sets.select {|vs| vs.oid == '2.16.840.1.113883.3.464.0001.49'}.first
    systems = ["CPT", "ICD-9-CM"]
    vs.concepts.map(&:code_system_name).uniq.length.must_equal 2
    (vs.concepts.map(&:code_system_name).uniq-systems).empty?.must_equal true
    vs.concepts.map(&:code).length.must_equal 52

  end  

end



module Measures
  module HTML
    class Writer 

      def self.generate_nqf_template(measure, population)
        locals ||= {}
        oid_map = {}
        measure.value_sets.each {|vs| oid_map[vs.oid] = vs.description }
        locals[:measure] = measure.as_hqmf_model
        locals[:population] = population
        locals[:oid_map] = oid_map
        locals[:pop_titles] = {'IPP'=>'Initial Patient Population', 'DENOM'=>'Denominator', 'NUMER'=>'Numerator', 'DENEXCEP'=>'Denominator Exceptions', 'DENEX'=>'Denominator Exclusions', 'MSRPOPL'=>'Measure Population', 'OBSERV'=>'Measure Observations'}
        locals[:erb_strings] = {rationale: "<%== rationale.to_json %>", firstname: "<%== patient_cache['first'] %>", lastname: "<%== patient_cache['last'] %>"}

        rendering_context = Measures::HTML::RenderingContext.new(locals)
        rendering_context.template_dir = File.join('lib','templates','erb','measure')
        erb = rendering_context.template('measure')
        eruby = Erubis::EscapedEruby.new(erb)
        result = eruby.result(rendering_context.my_binding)

        result
      end
      
      def self.finalize_template(measure_id, sub_id, patient_cache, template_dir)
        
        locals ||= {}

        locals[:rationale] = patient_cache['value']['rationale']
        locals[:patient_cache] = patient_cache['value']
      
        rendering_context = RenderingContext.new(locals)
        rendering_context.template_dir = template_dir
        erb = rendering_context.template("#{measure_id}#{sub_id}")
        eruby = Erubis::EscapedEruby.new(erb)
        result = eruby.result(rendering_context.my_binding)
        
        result
        
      end

    end

    class RenderingContext < OpenStruct

      attr_accessor :template_dir

      def my_binding
        binding
      end
      def conjunction_translator
        {'allTrue'=>'AND','atLeastOneTrue'=>'OR','XPRODUCT'=>'AND','UNION'=>'OR'}
      end
  
      def unit_text(unit, plural)
        @unit_decoder ||= {'a'=>'year','mo'=>'month','wk'=>'week','d'=>'day','h'=>'hour','min'=>'minute','s'=>'second'}
        if (@unit_decoder[unit])
          @unit_decoder[unit]+( plural ? 's' : '')
        else
          unit
        end
      end
  
      def false_color
        '#ED4337'
      end
      def true_color
        '#99FF66'
      end
  
      def temporal_text(key)
        @temporal_type_decoder ||= {'DURING'=>'During','SBS'=>'Starts Before Start of','SAS'=>'Starts After Start of',
                         'SBE'=>'Starts Before or During','SAE'=>'Starts After End of','EBS'=>'Ends Before Start of',
                         'EAS'=>'Ends During or After','EBE'=>'Ends Before or During','EAE'=>'Ends After End of',
                         'SDU'=>'Starts During','EDU'=>'Ends During','ECW'=>'Ends Concurrent with','SCW'=>'Starts Concurrent with',
                         'CONCURRENT'=>'Concurrent with'}
        @temporal_type_decoder[key]
      end
      def subset_text(key)
        @subset_type_decoder ||= {'COUNT'=>'COUNT', 'FIRST'=>'FIRST', 'SECOND'=>'SECOND', 'THIRD'=>'THIRD', 'FOURTH'=>'FOURTH',
                           'FIFTH'=>'FIFTH', 'RECENT'=>'MOST RECENT', 'LAST'=>'LAST', 'MIN'=>'MIN', 'MAX'=>'MAX',
                           'MEAN'=>'MEAN', 'MEDIAN'=>'MEDIAN', 'TIMEDIFF'=>'Difference between times', 'DATEDIFF'=>'Difference between dates'}
    
        @subset_type_decoder[key]
      end
  
      def template(template_name)
        File.read(File.join(@template_dir, "#{template_name}.html.erb"))
      end

      def partial(partial_name)
        template("_#{partial_name}")
      end
  
      def render(params)
        erb = partial(params[:partial])
        locals = params[:locals] || {}
        rendering_context = RenderingContext.new(locals)
        rendering_context.template_dir = self.template_dir
        eruby = Erubis::EscapedEruby.new(erb)
        eruby.result(rendering_context.my_binding)
      end
  
    end
  end
end
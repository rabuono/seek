module ROCrate
    # requires makehtml to be installed
    class WorkflowCratePreview

        attr_reader :script, :body_html, :html

        def initialize(workflow)
            @workflow = workflow
            @html = generate_html
            process_html
        end
        
        def generate_html
            jsonld=get_metedata_jsonld
            call_makehtml(jsonld)
        end

        private

        def get_metedata_jsonld
            @workflow.ro_crate do |crate|
                crate.metadata.generate # returns JSON-LD string
            end
        end

        def call_makehtml(jsonld)
            Dir.mktmpdir('ro-crate-preview') do |dir|                          
                f = ::File.write(::File.join(dir,'ro-crate-metadata.json'),jsonld)
                command = "cd #{dir} && makehtml ro-crate-metadata.json -c https://data.research.uts.edu.au/examples/ro-crate/examples/src/crate.js"
                line = Terrapin::CommandLine.new(command)
                line.run
                ::File.read(::File.join(dir,'ro-crate-preview.html'))
            end
        end

        def process_html
            noko = Nokogiri::HTML(@html)
            @body_html = noko.at_xpath('//body').inner_html
            @script = noko.at_xpath('//script').to_html
        end

    end
end
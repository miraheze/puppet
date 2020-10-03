require 'spec_helper'

describe 'generate_log' do

    context "With simple options" do
        let(:title) { 's_gsoc' }
        let(:options) { [
            {'source' => 's_gsoc2014'}, 
            {'destination' => 'd_gsoc'}
            ]
        }
        let(:expected) {
'log {
    source(s_gsoc2014);
    destination(d_gsoc);
};
'     }
        it 'Should generate a flat log' do
            result = scope.function_generate_log([options])
            expect(result).to be_a String
            expect(result).to eq expected
        end
    end

    context "With simple options" do
        let(:title) { 's_gsoc' }
        let(:options) { [
            {'source' => 's_gsoc2014'},
            {'junction' => [
                    {
                    'channel' => [
                        {'filter' => 'f_json'},
                        {'parser' => 'p_json'}
                        ]
                    },
                    {
                    'channel' => [
                        {'filter' => 'f_not_json'},
                        {'flags' => 'final'}
                    ]
                    }
                ]
            },
            {'destination' => 'd_gsoc'}
        ] }
        let(:expected) {
'log {
    source(s_gsoc2014);
    junction {
        channel {
            filter(f_json);
            parser(p_json);
        };
        channel {
            filter(f_not_json);
            flags(final);
        };
    };
    destination(d_gsoc);
};
'     }
        it 'Should generate a complex log' do
            result = scope.function_generate_log([options])
            expect(result).to be_a String
            expect(result).to eq expected
        end
    end



end

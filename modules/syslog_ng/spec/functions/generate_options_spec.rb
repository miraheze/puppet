require 'spec_helper'

describe 'generate_options' do

  context "With options" do
    let(:params) {{ 'log_fifo_size' => 2048,
                    'create_dirs' => 'yes'}}
    let(:expected) {
"options {
    create_dirs(yes);
    log_fifo_size(2048);
};
"

    }

    it 'Should fill the options statement' do
      result = scope.function_generate_options([params])
      expect(result).to be_a String
      expect(result).to eq expected
    end
  end

  context "Without options" do

    it "Should generate nothing" do
      result = scope.function_generate_options([{}])
      expect(result).to be_a String
      expect(result).to eq ""
    end

  end

end

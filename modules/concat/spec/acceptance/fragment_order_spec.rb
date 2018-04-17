require 'spec_helper_acceptance'

describe 'concat::fragment order' do
  basedir = default.tmpdir('concat')

  context 'with reverse order' do
    shared_examples 'order_by' do |order_by, match_output|
      pp = <<-MANIFEST
      concat { '#{basedir}/foo':
          order => '#{order_by}'
      }
      concat::fragment { '1':
        target  => '#{basedir}/foo',
        content => 'string1',
        order   => '15',
      }
      concat::fragment { '2':
        target  => '#{basedir}/foo',
        content => 'string2',
        # default order 10
      }
      concat::fragment { '3':
        target  => '#{basedir}/foo',
        content => 'string3',
        order   => '1',
      }
      MANIFEST

      it 'applies the manifest twice with no stderr' do
        apply_manifest(pp, catch_failures: true)
        apply_manifest(pp, catch_changes: true)
      end

      describe file("#{basedir}/foo") do
        it { is_expected.to be_file }
        its(:content) { is_expected.to match match_output }
      end
    end
    describe 'alpha' do
      it_behaves_like 'order_by', 'alpha', %r{string3string2string1}
    end
    describe 'numeric' do
      it_behaves_like 'order_by', 'numeric', %r{string3string2string1}
    end
  end

  context 'with normal order' do
    pp = <<-MANIFEST
      concat { '#{basedir}/foo': }
      concat::fragment { '1':
        target  => '#{basedir}/foo',
        content => 'string1',
        order   => '01',
      }
      concat::fragment { '2':
        target  => '#{basedir}/foo',
        content => 'string2',
        order   => '02'
      }
      concat::fragment { '3':
        target  => '#{basedir}/foo',
        content => 'string3',
        order   => '03',
      }
    MANIFEST

    it 'applies the manifest twice with no stderr' do
      apply_manifest(pp, catch_failures: true)
      apply_manifest(pp, catch_changes: true)
    end

    describe file("#{basedir}/foo") do
      it { is_expected.to be_file }
      its(:content) { is_expected.to match %r{string1string2string3} }
    end
  end
end
# concat::fragment order

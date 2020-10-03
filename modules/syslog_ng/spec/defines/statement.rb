shared_examples_for "Statement" do |id, type|
    let(:facts)  { { concat_basedir: '/dne',
                    osfamily: 'Debian',
                    os: { family: 'Debian', name: 'Ubuntu', release: { full: '14.04', major: '14.04' } },
                    operatingsystem: 'Ubuntu' } }

    let(:pre_condition) { 'include syslog_ng' }
    let(:title) { id }
    let(:type) { type }
    let(:options) {{}} 
         
    it do 
        should contain_concat__fragment("syslog_ng::"+type+" "+title)
    end
end

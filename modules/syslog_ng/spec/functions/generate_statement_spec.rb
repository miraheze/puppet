require 'spec_helper'

describe 'generate_statement' do

    let(:title) {'r_name'}
    let(:type) {'rewrite'}
    let(:param1_expected) {
%q!rewrite r_name {
    subst(
        'string',
        'replacement',
        value(
            field
        ),
        flags(
        )
    );
};
!}

    context "Array notation with one item can be omitted" do
        let(:param1) {{
            'type' => 'subst',
            'options' => [
                %q!'string'!,
                %q!'replacement'!,
                { 'value' => 'field' },
                { 'flags' => ''}
            ]
        }}
        it 'On parameters of options' do
            result = scope.function_generate_statement([title, type, [param1]])
            expect(result).to be_a String
            expect(result).to eq param1_expected
        end

        it 'On options' do
            result = scope.function_generate_statement([title, type, param1])
            expect(result).to be_a String
            expect(result).to eq param1_expected
        end
    end

    context "Type and options key can be reduced to the exact type of statement" do
        let(:param1) {{
            'subst' => [
                %q!'string'!,
                %q!'replacement'!,
                { 'value' => 'field' },
                { 'flags' => ''}
            ]
        }}
        it 'On parameters of options' do
            result = scope.function_generate_statement([title, type, [param1]])
            expect(result).to be_a String
            expect(result).to eq param1_expected
        end

        it 'On options' do
            result = scope.function_generate_statement([title, type, param1])
            expect(result).to be_a String
            expect(result).to eq param1_expected
        end

    end

    context "Array notation with one item can be omitted" do
        let(:param2) {{
            'type' => 'subst',
            'options' => [
                %q!'string'!,
                %q!'replacement'!,
                { 'value' => 'field' },
                { 'flags' => 'ignore-case, store-matches'}
            ]
        }}
        let(:param2_expected) {
%q!rewrite r_name {
    subst(
        'string',
        'replacement',
        value(
            field
        ),
        flags(
            ignore-case, store-matches
        )
    );
};
!}

        it 'On parameters of options' do
            result = scope.function_generate_statement([title, type, [param2]])
            expect(result).to be_a String
            expect(result).to eq param2_expected
        end

        it 'On options' do
            result = scope.function_generate_statement([title, type, param2])
            expect(result).to be_a String
            expect(result).to eq param2_expected
        end

    end

    context "With simple options" do
        let(:param1) {{
            'type' => 'subst',
            'options' => [
                %q!'string'!,
                %q!'replacement'!,
                { 'value' => ['field'] },
                { 'flags' => [  ]}
            ]
        }}

        let(:params) {[param1]}
        it 'Should generate rewrite rule' do
            result = scope.function_generate_statement([title, type, params])
            expect(result).to be_a String
            expect(result).to eq param1_expected
        end
    end

    context "Array statement" do
        let(:type) { 'source' }
        let(:title) { 's_external' }
        let(:params) {[
            { 'type' => 'udp',
              'options' => [
                {'ip' => [%q!'192.168.42.2'!]},
                {'port' => [514]},
                {'tls' => [
                    {'key_file' => ['"/opt/syslog-ng/etc/syslog-ng/key.d/syslog-ng.key"']},
                    {'cert_file'=> '"/opt/syslog-ng/etc/syslog-ng/cert.d/syslog-ng.cert"'},
                    {'peer_verify' => 'optional-untrusted'}
                ]}
                ]
            },
            { 'type' => 'tcp',
              'options' => [
                {'ip' => [%q!'192.168.42.2'!]},
                {'port' => [514]}
                ]
            },
            {
              'type' => 'syslog',
              'options' => [
                {'flags' => ['no-multi-line', 'no-parse']},
                {'ip' => [%q!'10.65.0.5'!]},
                {'keep-alive' => ['yes']},
                {'keep_hostname' => ['yes']},
                {'transport' => ['udp']}
                ]
            }
        ]}
      let(:expected) {
%q!source s_external {
    udp(
        ip(
            '192.168.42.2'
        ),
        port(
            514
        ),
        tls(
            key_file(
                "/opt/syslog-ng/etc/syslog-ng/key.d/syslog-ng.key"
            ),
            cert_file(
                "/opt/syslog-ng/etc/syslog-ng/cert.d/syslog-ng.cert"
            ),
            peer_verify(
                optional-untrusted
            )
        )
    );
    tcp(
        ip(
            '192.168.42.2'
        ),
        port(
            514
        )
    );
    syslog(
        flags(
            no-multi-line,
            no-parse
        ),
        ip(
            '10.65.0.5'
        ),
        keep-alive(
            yes
        ),
        keep_hostname(
            yes
        ),
        transport(
            udp
        )
    );
};
!}

        it 'Should generate source rule' do
            result = scope.function_generate_statement([title, type, params])
            expect(result).to be_a String
            expect(result).to eq expected
        end
    end
end

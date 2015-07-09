require 'spec_helper'

describe 'XCode CLI Installed' do
	describe command('pkgutil --pkg-info=com.apple.pkg.CLTools_Executables') do
		its(:exit_status) {should eq 0}
	end
end
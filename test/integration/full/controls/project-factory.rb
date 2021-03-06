# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

extra_service_account_email = attribute('extra_service_account_email')
project_id                  = attribute('project_id')
sa_role                     = attribute('sa_role')
service_account_email       = attribute('service_account_email')
usage_bucket_name           = attribute('usage_bucket_name')
usage_bucket_prefix         = attribute('usage_bucket_prefix')
credentials_path            = attribute('credentials_path')

ENV['CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE'] = File.absolute_path(
  credentials_path,
  File.join(__dir__, "../../../fixtures/full"))

control 'project-factory' do
  title 'Project Factory'

  describe command("gcloud projects describe #{project_id}") do
    its('exit_status') { should be 0 }
    its('stderr') { should eq '' }
  end

  describe command("gcloud services list --project #{project_id}") do
    its('exit_status') { should be 0 }
    its('stderr') { should eq '' }

    its('stdout') { should match(/compute\.googleapis\.com/) }
    its('stdout') { should match(/container\.googleapis\.com/) }
  end

  describe command("gcloud iam service-accounts list --project #{project_id} --format='json(email)'") do
    its('exit_status') { should be 0 }
    its('stderr') { should eq '' }

    let(:service_accounts) do
      if subject.exit_status == 0
        JSON.parse(subject.stdout, symbolize_names: true).map { |entry| entry[:email] }
      else
        []
      end
    end

    it "includes the Google App Engine API service account user" do
      expect(service_accounts).to include "#{project_id}@appspot.gserviceaccount.com"
    end

    it "includes the service account generated by the project factory" do
      expect(service_accounts).to include service_account_email
    end

    it "includes the service account created outside of the project factory" do
      expect(service_accounts).to include extra_service_account_email
    end
  end
end

control 'project-factory-sa-role' do
  title "Project factory service account role"

  only_if { !(sa_role.nil? || sa_role == '') }

  describe command("gcloud projects get-iam-policy #{project_id} --format=json") do
    its('exit_status') { should eq 0 }
    its('stderr') { should eq '' }

    let(:bindings) do
      if subject.exit_status == 0
        JSON.parse(subject.stdout, symbolize_names: true)[:bindings]
      else
        []
      end
    end

    it "does not overwrite the membership of the service account role" do
      binding = bindings.find { |b| b['role'] == sa_role }
      expect(binding).to be_nil

      expect(binding[:members]).to include "serviceAccount:#{extra_service_account_email}"
      expect(binding[:members]).to include "serviceAccount:#{service_account_email}"
    end
  end
end

control 'project-factory-usage' do
  title "Project factory usage bucket"

  only_if { !(usage_bucket_name.nil? || usage_bucket_prefix == '') }

  describe command("gcloud compute project-info describe --project #{project_id} --format='json(usageExportLocation)'") do
    its('exit_status') { should be 0 }
    its('stderr') { should eq '' }

    let(:usage) do
      if subject.exit_status == 0
        JSON.parse(subject.stdout, symbolize_names: true)[:usageExportLocation]
      else
        {}
      end
    end

    it { expect(usage[:bucketName]).to eq usage_bucket_name }
    it { expect(usage[:reportNamePrefix]).to eq usage_bucket_prefix }
  end
end

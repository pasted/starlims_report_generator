class ReportGenerator
	#Author Garan Jones
	#Demo script to show connecting to StarLIMS using TinyTds
  require 'yaml'
  require 'smarter_csv'
  require 'tiny_tds'
  require 'trollop'

  require_relative 'patient'
  
  def parse_file(file_name)
  	options = { :col_sep => "\t"}
  	patient_array = Array.new 
  	
  	if File.exists?(file_name) && ( File.stat(file_name).size > 0 )
  	
  		SmarterCSV.process( file_name, options ) do |csv|
  			this_patient = Patient.new
  			
  			this_patient.first_name	= csv.first[:first_name]
  			this_patient.last_name	=	csv.first[:last_name]
  			this_patient.dob	=	csv.first[:dob]
  			
  			patient_array.push(this_patient)
  		end
  		return patient_array
  	end
  end
  
  #Start of main body

  opts = Trollop::options do
  	opt :patients, "Filepath to Patient file to parse.", :type => String
  	opt :username, "Username for StarLIMS account.", :type => String
  	opt :password, "Password for StarLIMS account.", :type => String
  	opt :host, "Host server URL.", :type => String
  	opt :database, "StarLIMS Database name.", :type => String
  end

  filepath = opts[:patients].encode('UTF-8')
  username = opts[:username]
  password = opts[:password]
  host = opts[:host]
  database = opts[:database]
  
  
  errors = Array.new
  if !(filepath || filepath == '')
  	errors.push("Path to file with patient details required.")
  end
  if !(username || username == '')
  	errors.push("No username provided.")
  end
  if !(password || password == '')
  	errors.push("No password provided.")
  end
  if !(host || host == '')
  	errors.push("No host URL provided.")
  end
  if !(database || database == '')
  	errors.push("No StarLIMS database name provided.")
  end
  	  	
  if errors.length == 0
  	this_report_generator = ReportGenerator.new
  	
  	patients = this_report_generator.parse_file(filepath)

  	puts patients.length
  	
  	client = TinyTds::Client.new username: "#{username}", password: "#{password}", host: "#{host}", database: "#{database}"
  	
  	matched_patients = Array.new

  	patients.each do |this_patient|
  		
  		puts this_patient.inspect
  		result = client.execute("SELECT FOLDERS.PATIENTFIRSTNAME, FOLDERS.PATIENTSURNAME, FOLDERS.FOLDERNO, FOLDERS.DATEOFBIRTH, FOLDERS.NHSNUMBER , SAMPLECONTAINERS.LOCATION_CODE, SAMPLECONTAINERS.EXTERNAL_ID, SAMPLECONTAINERS.SAMPLE_TYPE, SAMPLECONTAINERS.CONC FROM FOLDERS INNER JOIN SAMPLECONTAINERS ON FOLDERS.FOLDERNO = SAMPLECONTAINERS.FOLDERNO AND ( UPPER(FOLDERS.PATIENTFIRSTNAME) = UPPER('#{this_patient.first_name}') AND UPPER(FOLDERS.PATIENTSURNAME) = UPPER('#{this_patient.last_name}') )" )
  		result.fields

  		result.each do |row|
  			new_patient = Patient.new
  			new_patient.first_name = row['PATIENTFIRSTNAME']
  			new_patient.last_name = row['PATIENTSURNAME']
  			new_patient.ex_number = row['FOLDERNO']
  			new_patient.dob = row['DATEOFBIRTH']
  			new_patient.nhs_number = row['NHSNUMBER']
  			new_patient.location_code = row['LOCATION_CODE']
  			new_patient.external_id = row['EXTERNAL_ID']
  			new_patient.sample_type = row['SAMPLE_TYPE']
  			new_patient.conc = row['CONC']
  			
  			matched_patients.push(new_patient)
  		end
  		sleep 1
  		
  	end

  	column_names = ["first_name","last_name","ex_number","dob","nhs_number","location_code","external_id","sample_type","conc"]
  	puts matched_patients.inspect

  	File.open("#{Time.now.to_i}_matched_patients.yaml", 'w') {|f| f.write(matched_patients.to_yaml) }
  	CSV.open("#{Time.now.to_i}_matched_patients.csv", "wb") do |csv|
      csv << column_names
      matched_patients.each do |patient|
        csv << ["#{patient.first_name}","#{patient.last_name}","#{patient.ex_number}","#{patient.dob}","#{patient.nhs_number}","#{patient.location_code}","#{patient.external_id}","#{patient.sample_type}", "#{patient.conc}"]
      end
    end
  	

  else
  	puts "#{errors.inspect}"
  end

end

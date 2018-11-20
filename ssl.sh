#!/usr/bin/env bash
sudo rm -f ~/.rnd
if grep -qs "CentOS release 5" "/etc/redhat-release"; then
	echo "CentOS 5 is too old and not supported"
	exit
fi

if [[ -e /etc/debian_version ]]; then
	OS=debian
	RCLOCAL='/etc/rc.local'
elif [[ -e /etc/centos-release || -e /etc/redhat-release ]]; then
	OS=centos
else
	echo "Looks like you aren't running this installer on a Debian, Ubuntu or CentOS system"
	exit
fi

# path key name
genCA() {
	if [[ ! -d "$1" ]]; then
		echo "Storage path not found: $1"
		exit 1
	fi
	
	cd "$1" || exit 1
	
	if [[ ! -e "$2" ]]; then
		echo "Key file not found: $2"
		exit 1
	fi
	
	read -p "CA TTL in days: " -e -i "3650" TTL
	
	echo "Generating $3.crt"
	
	openssl req -x509 -new -nodes -key "$2" -sha256 -days "${TTL}" -out "$3".crt
	
	echo "Done"
}

# path name
genRSAkey() {
	if [[ ! -d "$1" ]]; then
		echo "Storage path not found: $1"
		exit 1
	fi
	
	cd "$1" || exit 1
	
	read -p "Key lenght: " -e -i "4096" KL
	
	echo "Generating $2.key"
	
	openssl genrsa -out "$2".key "${KL}"
	
	echo "Done"
}

# path name
genECDSAkey() {
	if [[ ! -d "$1" ]]; then
		echo "Storage path not found: $1"
		exit 1
	fi
	
	cd "$1" || exit 1
	
	read -p "Which elliptic curve to use: " -e -i "prime256v1" EP
	
	echo "Generating $2.key"
	
	openssl ecparam -name "${EP}" -genkey -out "$2".key
	
	echo "Done"
}

# path rootCA CAkey CSR CSRkey
genCertSSL() {
	if [[ ! -d "$1" ]]; then
		echo "Storage path not found: $1"
		exit 1
	fi
	
	cd "$1" || exit 1
	
	if [[ ! -e "$2" ]]; then
		echo "CA file not found: $2"
		exit 1
	fi
	
	if [[ ! -e "$3" ]]; then
		echo "Key file not found: $3"
		exit 1
	fi
	
	if [[ ! -e "$4" ]]; then
		echo "Cert request file not found: $4"
		exit 1
	fi
	
	if [[ ! -e "$5" ]]; then
		echo "Cert request key file not found: $5"
		exit 1
	fi
	
	DIR=$(dirname "$1")
	FILENAME=$(basename "${6:-$4}")
	
	read -p "TTL in days: " -e -i "1825" TTL
	
	echo "Generating ${FILENAME%.*}.crt"
	
	if [[ ! -e "extfile.cnf" ]]; then
		echo "subjectAltName=DNS:copy:commonName,IP:127.0.0.1" > extfile.cnf
	fi
	
	openssl x509 \
		-req -in "$4" \
		-CA rootCA.crt \
		-CAkey "$3" \
		-CAcreateserial \
		-out "${FILENAME%.*}".crt \
		-extfile extfile.cnf \
		-days "${TTL}" \
		-sha256
		
	echo "Done"
	echo "Generating ${FILENAME%.*}.pem"
	cat "$5" "${FILENAME%.*}".crt "$2" > "${FILENAME%.*}".pem
#	cat "${FILENAME%.*}".pem "$2" > fullchain.pem
	
	echo "File in ${DIR}:"
	find -type f -mindepth 1 -maxdepth 1 "${DIR}"
}

# path rootCA CSRkey name
genCertRequest() {
	if [[ ! -d "$1" ]]; then
		echo "Storage path not found: $1"
		exit 1
	fi
	
	cd "$1" || exit 1
	
	if [[ ! -e "$2" ]]; then
		echo "CA file not found: $2"
		exit 1
	fi
	
	if [[ ! -e "$3" ]]; then
		echo "CSR key file not found: $3"
		exit 1
	fi
	
	read -p "Certificate Signature Algorithn: " -e -i "sha256" CSA
	
	echo "Generating $4.csr"
	openssl req -new -"${CSA}" -key "$3" -out "$4".csr
	echo "Done"
	
	echo "File in ${DIR}:"
	find -type f -mindepth 1 -maxdepth 1 "${DIR}"
}

genDHParam() {
	if [[ ! -d "$1" ]]; then
		echo "Storage path not found: $1"
		exit 1
	fi
	
	cd "$1" || exit 1

	PEMFILE="$1/dhparam".pem
	
	echo "Gen DH"
	read -p "DH parameter lenght: " -e -i "4096" DHL
	
	echo "Generating dhparam.pem"
	openssl dhparam -dsaparam -out "${PEMFILE}" "${DHL}"
	echo "Done"
	
	echo "File in ${DIR}:"
	find -type f -mindepth 1 -maxdepth 1 "${DIR}"
}

# Prepare openssl
echo "Setting up for openssl"
if [[ "$OS" = 'debian' ]]; then
	sudo apt-get install -y openssl
else
	sudo yum install -y openssl
fi

# Get current path
CDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
# Begin
while :
	do
	clear
	echo "What chiper do you want?"
	echo "1) RSA"
	echo "2) ECDSA"
	echo "3) Cert request"
	echo "4) Sign cert"
	echo "5) Gen DHParam"
	echo "0) Exit"
	read -p "Select an option [0-5]: " OPTION
	case "${OPTION}" in
		1)
			echo "Where path do you want to store files?"
			read -p "Select path to store files: " -e -i "${CDIR}/rsa" FPATH
			read -p "Full domain name (File Name): " -e -i "server" DN
			mkdir -p "${FPATH}"
			
			if [[ ! -e "${FPATH}/rootCA.key" ]]; then
			echo "Create rootCA key"
			genRSAkey "${FPATH}" "rootCA"
			fi
			if [[ ! -e "${FPATH}/rootCA.crt" ]]; then
			echo "Create rootCA crt"
			genCA "${FPATH}" "rootCA.key" "rootCA"
			fi
			
			echo "Create host key"
			genRSAkey "${FPATH}" "${DN}"
			echo "Create host cert request"
			genCertRequest "${FPATH}" "rootCA.crt" "${DN}.key" "${DN}"
			echo "Create host cert sign"
			genCertSSL "${FPATH}" "rootCA.crt" "rootCA.key" "${DN}.csr" "${DN}.key"
		;;
		2)
			echo "Where path do you want to store files?"
			read -p "Select path to store files: " -e -i "${CDIR}/ecdsa" FPATH
			read -p "Full domain name (File Name): " -e -i "server" DN
			mkdir -p "${FPATH}"
			
			if [[ ! -e "${FPATH}/rootCA.key" ]]; then
			echo "Create rootCA key"
			genECDSAkey "${FPATH}" "rootCA"
			fi
			if [[ ! -e "${FPATH}/rootCA.crt" ]]; then
			echo "Create rootCA crt"
			genCA "${FPATH}" "rootCA.key" "rootCA"
			fi
			
			echo "Create host key"
			genECDSAkey "${FPATH}" "${DN}"
			echo "Create host cert request"
			genCertRequest "${FPATH}" "rootCA.crt" "${DN}.key" "${DN}"
			echo "Create host cert sign"
			genCertSSL "${FPATH}" "rootCA.crt" "rootCA.key" "${DN}.csr" "${DN}.key"
		;;
		3)
		while :
		do
			clear
			echo "What chiper do you want?"
			echo "1) RSA"
			echo "2) ECDSA"
			echo "0) Back to main menu"
			read -p "Select an option [0-2]: " OPTION
			case "${OPTION}" in
			1)
				echo "Where path do you want to store files?"
				read -p "Select path to store files: " -e -i "${CDIR}/rsa" FPATH
				read -p "Full domain name (File Name): " -e -i "server" DN
				mkdir -p "${FPATH}"
			
				if [[ ! -e "${FPATH}/rootCA.key" ]]; then
				echo "Create rootCA key"
				genRSAkey "${FPATH}" "rootCA"
				fi
				if [[ ! -e "${FPATH}/rootCA.crt" ]]; then
				echo "Create rootCA crt"
				genCA "${FPATH}" "rootCA.key" "rootCA"
				fi
			
				echo "Create host key"
				genRSAkey "${FPATH}" "${DN}"
				echo "Create host cert request"
				genCertRequest "${FPATH}" "rootCA.crt" "${DN}.key" "${DN}"
			;;
			2)
				echo "Where path do you want to store files?"
				read -p "Select path to store files: " -e -i "${CDIR}/ecdsa" FPATH
				read -p "Full domain name (File Name): " -e -i "server" DN
				mkdir -p "${FPATH}"
			
				if [[ ! -e "${FPATH}/rootCA.key" ]]; then
				echo "Create rootCA key"
				genECDSAkey "${FPATH}" "rootCA"
				fi
				if [[ ! -e "${FPATH}/rootCA.crt" ]]; then
				echo "Create rootCA crt"
				genCA "${FPATH}" "rootCA.key" "rootCA"
				fi
			
				echo "Create host key"
				genECDSAkey "${FPATH}" "${DN}"
				echo "Create host cert request"
				genCertRequest "${FPATH}" "rootCA.crt" "${DN}.key" "${DN}"
			;;
			0)
				break
			;;
			esac
		done
		;;
		4)
			read -p "Select path to store files: " -e -i "${CDIR}/" FPATH
			read -p "In file name: " -e -i "server" IN
			# read -p "Out file name: " -e -i "${IN}" ON
			read -p "subjectAltName: " -e -i "DNS:copy:commonName,IP:127.0.0.1" SAN
			echo "subjectAltName=${SAN}" > ${FPATH}/extfile.cnf			
			echo "extendedKeyUsage = serverAuth, clientAuth" >> ${FPATH}/extfile.cnf
			echo "Create host cert sign"
			genCertSSL "${FPATH}" "rootCA.crt" "rootCA.key" "${IN}.csr" "${IN}.key"
		;;
		5)
			read -p "Select path to store files: " -e -i "${CDIR}" FPATH
			genDHParam "${FPATH}"
		;;
		0)
			exit 0
		;;
	esac
done
exit 0

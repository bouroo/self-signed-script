#!/bin/bash

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

genRSASSL() {
	if [[ ! -d "$1" ]]; then
		echo "Storage path not found"
		exit 1
	fi
	
	mkdir -p "$1/rsa/"
	cd "$1/rsa/"
	
	read -p "Full domain name: " -e -i "server" DN
	read -p "Key lenght: " -e -i "4096" KL
	
	echo "Generating ${DN}.key"
	openssl genrsa -out "${DN}".key "${KL}"
	echo "Done"
	
	genCertSSL "$1/rsa/${DN}.key"
}

genECDSASSL() {
	if [[ ! -d "$1" ]]; then
		echo "Storage path not found"
		exit 1
	fi
	
	mkdir -p "$1/ecdsa/"
	cd "$1/ecdsa/"
	
	read -p "Full domain name: " -e -i "server" DN
	
	echo "Generating ${DN}.key"
	openssl ecparam -name secp521r1 -genkey -out "${DN}".key
	echo "Done"
	
	genCertSSL "$1/ecdsa/${DN}.key"
}

genCertSSL() {
	if [[ ! -e "$1" ]]; then
		echo "Key file not found"
		exit 1
	fi
	
	DIR=$(dirname "$1")
	FILENAME=$(basename "$1")
	CRTFILE="${DIR}/${FILENAME%.*}".crt
	PEMFILE="${DIR}/${FILENAME%.*}".pem
	
	read -p "TTL in days: " -e -i "1825" TTL
	
	echo "Generating ${FILENAME%.*}.crt"
	openssl req -new -x509 -sha512 -key "$1" -out "${CRTFILE}" -days "${TTL}"
	echo "Done"
	echo "Generating ${FILENAME%.*}.pem"
	cat "$1" "${CRTFILE}" > "${PEMFILE}"
	echo "Done"
	
	read -p "Do you want to gen DH paramemter [y/n]: " -e -i "y" DH
	if [[ "${DH}" = "y"  ]]; then
		genDHParam "${DIR}"
	else
		echo "File in ${DIR}:"
		find "${DIR}" -type f -mindepth 1 -maxdepth 1
	fi
}

genCertRequest() {
	if [[ ! -e "$1" ]]; then
		echo "Key file not found"
		exit 1
	fi
	
	DIR=$(dirname "$1")
	FILENAME=$(basename "$1")
	CSRFILE="${DIR}/${FILENAME%.*}".csr
	#extension="${filename##*.}"
	#filename="${filename%.*}"
	
	read -p "Certificate Signature Algorithn: " -e -i "sha512" CSA
	
	echo "Generating ${FILENAME%.*}.csr"
	openssl req -new -"${CSA}" -key "$1" -out "${CSRFILE}"
	echo "Done"
	
	echo "File in ${DIR}:"
	find "${DIR}" -type f -mindepth 1 -maxdepth 1
}

genDHParam() {
	if [[ ! -d "$1" ]]; then
		echo "Storage path not found"
		exit 1
	fi
	
	DIR=$(dirname "$1")
	PEMFILE="${DIR}/dhparam".pem
	
	echo "Gen DH"
	read -p "DH parameter lenght: " -e -i "4096" DHL
	
	echo "Generating dhparam.pem"
	openssl dhparam -out "${PEMFILE}" "${DHL}"
	echo "Done"
	
	echo "File in ${DIR}:"
	find "${DIR}" -type f -mindepth 1 -maxdepth 1
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
	echo "0) Exit"
	read -p "Select an option [0-3]: " OPTION
	case "${OPTION}" in
		1)
			echo "Where path do you want to store files?"
			read -p "Select path to store files: " -e -i "${CDIR}" FPATH
			genRSASSL "${FPATH}"
			exit 0
		;;
		2)
			echo "Where path do you want to store files?"
			read -p "Select path to store files: " -e -i "${CDIR}" FPATH
			genECDSASSL "${FPATH}"			
			exit 0
		;;
		3)
			read -p "Path to private key: " -e -i "server.key" PK
			genCertRequest "$PK"			
			exit 0
		;;
		0)
			exit 0
		;;
	esac
done
exit 0

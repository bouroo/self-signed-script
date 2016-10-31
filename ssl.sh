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
		echo "Storage path not found"
		exit 1
	fi
    
    cd "$1" || exit 1
    
    if [[ ! -e "$2" ]]; then
		echo "Key file not found"
		exit 1
	fi
	
    read -p "CA TTL in days: " -e -i "3650" TTL
    
    echo "Generating $3.crt"
    
    openssl req -x509 -new -nodes -key "$2" -sha512 -days "${TTL}" -out "$3".crt
    
	echo "Done"
}

# path name
genRSAkey() {
	if [[ ! -d "$1" ]]; then
		echo "Storage path not found"
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
		echo "Storage path not found"
		exit 1
	fi
	
	cd "$1" || exit 1
    
    read -p "Which elliptic curve to use: " -e -i "secp384r1" EP
	
	echo "Generating $2.key"
    
	openssl ecparam -name "${EP}" -genkey -out "$2".key
    
	echo "Done"
}

# path rootCA CAkey CSR CSRkey
genCertSSL() {
	if [[ ! -d "$1" ]]; then
		echo "Storage path not found"
		exit 1
	fi
    
    cd "$1" || exit 1
    
    if [[ ! -e "$2" ]]; then
		echo "CA file not found"
		exit 1
	fi
    
    if [[ ! -e "$3" ]]; then
		echo "Key file not found"
		exit 1
	fi
    
    if [[ ! -e "$4" ]]; then
		echo "Cert request file not found"
		exit 1
	fi
    
    if [[ ! -e "$5" ]]; then
		echo "Cert request key file not found"
		exit 1
	fi
	
	DIR=$(dirname "$1")
	FILENAME=$(basename "$4")
	
	read -p "TTL in days: " -e -i "1825" TTL
	
	echo "Generating ${FILENAME%.*}.crt"
    
    openssl x509 -req -in "$4" -CA rootCA.crt -CAkey "$3" -CAcreateserial -out "${FILENAME%.*}".crt -days "${TTL}"
    
	echo "Done"
	echo "Generating ${FILENAME%.*}.pem"
	cat "$5" "${FILENAME%.*}".crt "$2" > "${FILENAME%.*}".pem
	
	read -p "Do you want to gen DH paramemter [y/n]: " -e -i "y" DH
	if [[ "${DH}" = "y"  ]]; then
		genDHParam "${DIR}"
	else
		echo "File in ${DIR}:"
		find "${DIR}" -type f -mindepth 1 -maxdepth 1
	fi
}

# path rootCA CSRkey name
genCertRequest() {
	if [[ ! -d "$1" ]]; then
		echo "Storage path not found"
		exit 1
	fi
    
    cd "$1" || exit 1
    
    if [[ ! -e "$2" ]]; then
		echo "CA file not found"
		exit 1
	fi
    
    if [[ ! -e "$3" ]]; then
		echo "CSR key file not found"
		exit 1
	fi
	
	read -p "Certificate Signature Algorithn: " -e -i "sha512" CSA
	
	echo "Generating $4.csr"
	openssl req -new -"${CSA}" -key "$3" -out "$4".csr
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
	openssl dhparam -dsaparam -out "${PEMFILE}" "${DHL}"
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
            read -p "Full domain name: " -e -i "server" DN
            mkdir -p "${FPATH}/rsa"
            
            if [[ ! -e "${FPATH}/rsa/rootCA.key" ]]; then
            echo "Create rootCA key"
			genRSAkey "${FPATH}/rsa" "rootCA"
            fi
            if [[ ! -e "${FPATH}/rsa/rootCA.crt" ]]; then
            echo "Create rootCA crt"
            genCA "${FPATH}/rsa" "rootCA.key" "rootCA"
            fi
            
            echo "Create host key"
			genRSAkey "${FPATH}/rsa" "${DN}"
            echo "Create host cert request"
            genCertRequest "${FPATH}/rsa" "rootCA.crt" "${DN}.key" "${DN}"
            echo "Create host cert sign"
            genCertSSL "${FPATH}/rsa" "rootCA.crt" "rootCA.key" "${DN}.csr" "${DN}.key"
			exit 0
		;;
		2)
			echo "Where path do you want to store files?"
			read -p "Select path to store files: " -e -i "${CDIR}" FPATH
            read -p "Full domain name: " -e -i "server" DN
            mkdir -p "${FPATH}/ecdsa"
            
            if [[ ! -e "${FPATH}/ecdsa/rootCA.key" ]]; then
            echo "Create rootCA key"
			genECDSAkey "${FPATH}/ecdsa" "rootCA"
            fi
            if [[ ! -e "${FPATH}/ecdsa/rootCA.crt" ]]; then
            echo "Create rootCA crt"
            genCA "${FPATH}/ecdsa" "rootCA.key" "rootCA"
            fi
            
            echo "Create host key"
			genECDSAkey "${FPATH}/ecdsa" "${DN}"
            echo "Create host cert request"
            genCertRequest "${FPATH}/ecdsa" "rootCA.crt" "${DN}.key" "${DN}"
            echo "Create host cert sign"
            genCertSSL "${FPATH}/ecdsa" "rootCA.crt" "rootCA.key" "${DN}.csr" "${DN}.key"
			exit 0
		;;
		3)
            read -p "Select path to store files: " -e -i "${CDIR}" FPATH
			read -p "rootCA cert: " -e -i "rootCA.crt" RCAC
			read -p "CSR key: " -e -i "host.key" CSRK
			read -p "Full domain name: " -e -i "server" DN
			genCertRequest "${FPATH}" "${RCAC}" "${CSRK}" "${DN}"
			exit 0
		;;
		0)
			exit 0
		;;
	esac
done
exit 0

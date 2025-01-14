#!/bin/bash

CYAN='\033[1;36m'
NC='\033[0m'

trap ctrl_c INT
function ctrl_c {
    exit 11;
}

BOOTSTRAP=0 # 1 if chain bootstrapping (bios, system contract, etc.) is needed, else 0
RECOMPILE_AND_RESET_EOSIO_CONTRACTS=0
BUILD=0
HELP=0
EOSIO_CONTRACTS_ROOT=/home/kedar/eosio.contracts/build/contracts/
NODEOS_HOST="127.0.0.1"
NODEOS_PROTOCOL="http"
NODEOS_PORT="8888"
NODEOS_LOCATION="${NODEOS_PROTOCOL}://${NODEOS_HOST}:${NODEOS_PORT}"

alias cleos="cleos --url=${NODEOS_LOCATION}"

#######################################
## HELPERS

function balance {
    cleos get table everipediaiq $1 accounts | jq ".rows[0].balance" | tr -d '"' | awk '{print $1}'
}

assert ()
{

    if [ $1 -eq 0 ]; then
        FAIL_LINE=$( caller | awk '{print $1}')
        echo -e "Assertion failed. Line $FAIL_LINE:"
        head -n $FAIL_LINE $BASH_SOURCE | tail -n 1
        exit 99
    fi
}

ipfsgen () {
    echo -e "Qm$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 44 | head -n 1)"
}

titlegen () {
    cat /dev/urandom | tr -dc 'a-z\-' | fold -w 15 | head -n 1
}

#################################

# Parse args
OPTIONS=$(getopt -o bsh --long build,bootstrap,help: -n test.sh -- "$@")
if [ $? != 0 ] ; then echo -e "Failed parsing options." >&2 ; exit 1 ; fi
eval set -- "$OPTIONS"
while true; do
  case "$1" in
    -h | --help ) HELP=1; shift;;
    -b | --build ) BUILD=1; shift ;;
    -s | --bootstrap ) BOOTSTRAP=1; shift ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

if [ $HELP -eq 1 ]; then
    echo -e "Usage ./test.sh [-b | --build][-s | --bootstrap][-h | --help]";
    exit 0
fi


if [ ! -e test.sh ]; then
    echo "Testing from wrong directory. Must be in test/ directory"
    exit 1;
fi

# Don't allow tests on mainnet
CHAIN_ID=$(cleos get info | jq ".chain_id" | tr -d '"')
if [ $CHAIN_ID = "aca376f206b8fc25a6ed44dbdc66547c36c6c33e3a119ffbeaef943642f0e906" ]; then
    >&2 echo -e "Cannot run test on mainnet"
    exit 1
fi

# Build
if [ $BUILD -eq 1 ]; then
    sed -i -e 's/REWARD_INTERVAL = 1800/REWARD_INTERVAL = 5/g' ../eparticlectr/eparticlectr.hpp
    sed -i -e 's/DEFAULT_VOTING_TIME = 43200/DEFAULT_VOTING_TIME = 3/g' ../eparticlectr/eparticlectr.hpp
    sed -i -e 's/STAKING_DURATION = 21 \* 86400/STAKING_DURATION = 5/g' ../eparticlectr/eparticlectr.hpp
    cd ..
    bash build.sh
    cd test
    sed -i -e 's/REWARD_INTERVAL = 5/REWARD_INTERVAL = 1800/g' ../eparticlectr/eparticlectr.hpp
    sed -i -e 's/DEFAULT_VOTING_TIME = 3/DEFAULT_VOTING_TIME = 43200/g' ../eparticlectr/eparticlectr.hpp
    sed -i -e 's/STAKING_DURATION = 5/STAKING_DURATION = 21 \* 86400/g' ../eparticlectr/eparticlectr.hpp
fi

if [ $BOOTSTRAP -eq 1 ]; then
    bash bootstrap.sh
fi

## Deploy contracts
echo -e "${CYAN}-----------------------DEPLOYING EVERIPEDIA CONTRACTS AGAIN-----------------------${NC}"
cleos set contract everipediaiq ../everipediaiq/
cleos set contract eparticlectr ../eparticlectr/
cleos set contract iqutxoiqutxo ../iqutxo/

# No transfer fees for privileged accounts
OLD_BALANCE1=$(balance eptestusersa)
OLD_BALANCE2=$(balance eptestusersb)
OLD_BALANCE3=$(balance eptestusersc)
OLD_BALANCE4=$(balance eptestusersd)
OLD_BALANCE5=$(balance eptestuserse)
OLD_BALANCE6=$(balance eptestusersf)
OLD_BALANCE7=$(balance eptestusersg)
OLD_FEE_BALANCE=$(balance epiqtokenfee)
OLD_SUPPLY=$(cleos get table everipediaiq IQ stat | jq ".rows[0].supply" | tr -d '"' | awk '{print $1}')

# Test IQ transfers
echo -e "${CYAN}-----------------------MOVING TOKENS FROM THE CONTRACT TO SOME USERS -----------------------${NC}"
cleos push action everipediaiq transfer '["everipediaiq", "eptestusersa", "10000.000 IQ", "test"]' -p everipediaiq
assert $(bc <<< "$? == 0")
cleos push action everipediaiq transfer '["everipediaiq", "eptestusersb", "10000.000 IQ", "test"]' -p everipediaiq
assert $(bc <<< "$? == 0")
cleos push action everipediaiq transfer '["everipediaiq", "eptestusersc", "10000.000 IQ", "test"]' -p everipediaiq
assert $(bc <<< "$? == 0")
cleos push action everipediaiq transfer '["everipediaiq", "eptestusersd", "10000.000 IQ", "test"]' -p everipediaiq
assert $(bc <<< "$? == 0")
cleos push action everipediaiq transfer '["everipediaiq", "eptestuserse", "10000.000 IQ", "test"]' -p everipediaiq
assert $(bc <<< "$? == 0")
cleos push action everipediaiq transfer '["everipediaiq", "eptestusersf", "10000.000 IQ", "test"]' -p everipediaiq
assert $(bc <<< "$? == 0")
cleos push action everipediaiq transfer '["everipediaiq", "eptestusersg", "10000.000 IQ", "test"]' -p everipediaiq
assert $(bc <<< "$? == 0")

NEW_BALANCE1=$(balance eptestusersa)
NEW_BALANCE2=$(balance eptestusersb)
NEW_BALANCE3=$(balance eptestusersc)
NEW_BALANCE4=$(balance eptestusersd)
NEW_BALANCE5=$(balance eptestuserse)
NEW_BALANCE6=$(balance eptestusersf)
NEW_BALANCE7=$(balance eptestusersg)

assert $(bc <<< "$NEW_BALANCE1 - $OLD_BALANCE1 == 10000")
assert $(bc <<< "$NEW_BALANCE2 - $OLD_BALANCE2 == 10000")
assert $(bc <<< "$NEW_BALANCE3 - $OLD_BALANCE3 == 10000")
assert $(bc <<< "$NEW_BALANCE4 - $OLD_BALANCE4 == 10000")
assert $(bc <<< "$NEW_BALANCE5 - $OLD_BALANCE5 == 10000")
assert $(bc <<< "$NEW_BALANCE6 - $OLD_BALANCE6 == 10000")
assert $(bc <<< "$NEW_BALANCE7 - $OLD_BALANCE7 == 10000")

# Standard transfers
OLD_BALANCE1=$(balance eptestusersa)
OLD_BALANCE2=$(balance eptestusersb)
OLD_BALANCE3=$(balance eptestusersc)
OLD_BALANCE4=$(balance eptestusersd)
OLD_BALANCE5=$(balance eptestuserse)
OLD_BALANCE6=$(balance eptestusersf)
OLD_BALANCE7=$(balance eptestusersg)

# Standard transfers
echo -e "${CYAN}-----------------------MOVING TOKENS FROM ONE USER TO THE NEXT, UNSAFELY-----------------------${NC}"
cleos push action everipediaiq transfer '["eptestusersa", "eptestusersb", "1000.000 IQ", "test"]' -p eptestusersa
assert $(bc <<< "$? == 0")
cleos push action everipediaiq transfer '["eptestusersa", "eptestusersc", "1000.000 IQ", "test"]' -p eptestusersa
assert $(bc <<< "$? == 0")
cleos push action everipediaiq transfer '["eptestusersa", "eptestusersd", "1000.000 IQ", "test"]' -p eptestusersa
assert $(bc <<< "$? == 0")
cleos push action everipediaiq transfer '["eptestusersa", "eptestuserse", "1000.000 IQ", "test"]' -p eptestusersa
assert $(bc <<< "$? == 0")
cleos push action everipediaiq transfer '["eptestusersa", "eptestusersf", "1000.000 IQ", "test"]' -p eptestusersa
assert $(bc <<< "$? == 0")
cleos push action everipediaiq transfer '["eptestusersa", "eptestusersg", "1000.000 IQ", "test"]' -p eptestusersa
assert $(bc <<< "$? == 0")

NEW_BALANCE1=$(balance eptestusersa)
NEW_BALANCE2=$(balance eptestusersb)
NEW_BALANCE3=$(balance eptestusersc)
NEW_BALANCE4=$(balance eptestusersd)
NEW_BALANCE5=$(balance eptestuserse)
NEW_BALANCE6=$(balance eptestusersf)
NEW_BALANCE7=$(balance eptestusersg)

assert $(bc <<< "$OLD_BALANCE1 - $NEW_BALANCE1 == 6000")
assert $(bc <<< "$NEW_BALANCE2 - $OLD_BALANCE2 == 1000")
assert $(bc <<< "$NEW_BALANCE3 - $OLD_BALANCE3 == 1000")
assert $(bc <<< "$NEW_BALANCE4 - $OLD_BALANCE4 == 1000")
assert $(bc <<< "$NEW_BALANCE5 - $OLD_BALANCE5 == 1000")
assert $(bc <<< "$NEW_BALANCE6 - $OLD_BALANCE6 == 1000")
assert $(bc <<< "$NEW_BALANCE7 - $OLD_BALANCE7 == 1000")

# Failed transfers
echo -e "${CYAN}-----------------------NEXT THREE TRANSFERS SHOULD FAIL-----------------------${NC}"
cleos push action everipediaiq transfer '["eptestusersa", "eptestusersb", "10000000.000 IQ", "test"]' -p eptestusersa
assert $(bc <<< "$? == 1")
cleos push action everipediaiq transfer '["eptestusersa", "eptestusersb", "0.000 IQ", "test"]' -p eptestusersa
assert $(bc <<< "$? == 1")
cleos push action everipediaiq transfer '["eptestusersa", "eptestusersb", "-100.000 IQ", "test"]' -p eptestusersa
assert $(bc <<< "$? == 1")

echo -e "${CYAN}-----------------------TRANSFER AND ISSUE UTXO-----------------------${NC}"
cleos push action everipediaiq transfer '["everipediaiq", "iqutxoiqutxo", "1000000.000 IQ", "EOS7PoGq46ssqeGh8ZNScWQxqbwg5RNvLAwVw3i5dQcZ3a1h9nRyr"]' -p everipediaiq
assert $(bc <<< "$? == 0")

echo -e "${CYAN}-----------------------UTXO TRANSFERS-----------------------${NC}"
LAST_NONCE1=$(cleos get table iqutxoiqutxo iqutxoiqutxo accounts | jq '.rows[] | select(.publickey == "EOS7PoGq46ssqeGh8ZNScWQxqbwg5RNvLAwVw3i5dQcZ3a1h9nRyr") | .last_nonce')
LAST_NONCE2=$(cleos get table iqutxoiqutxo iqutxoiqutxo accounts | jq '.rows[] | select(.publickey == "EOS6KnJPV1mDuS8pYuLucaWzkwbWjGPeJsfQDpqc7NZ4F7zTQh4Wt") | .last_nonce')
if [ -z $LAST_NONCE1 ]; then LAST_NONCE1=0; fi
if [ -z $LAST_NONCE2 ]; then LAST_NONCE2=0; fi
NONCE1=$(echo "$LAST_NONCE1 + 1" | bc)
NONCE2=$(echo "$LAST_NONCE1 + 2" | bc)
NONCE3=$(echo "$LAST_NONCE2 + 1" | bc)
NONCE4=$(echo "$LAST_NONCE1 + 3" | bc)
NONCE5=$(echo "$LAST_NONCE1 + 4" | bc)
NONCE6=$(echo "$LAST_NONCE1 + 5" | bc)
SIG1=$(node ../iqutxo/js/sign.js EOS7PoGq46ssqeGh8ZNScWQxqbwg5RNvLAwVw3i5dQcZ3a1h9nRyr EOS6KnJPV1mDuS8pYuLucaWzkwbWjGPeJsfQDpqc7NZ4F7zTQh4Wt 2000000 10 $NONCE1 "test transfer" 5KQRA6BBHEHSbmvio3S9oFfVERvv79XXppmYExMouSBqPkZTD79)
cleos push action iqutxoiqutxo transfer "[\"EOS7PoGq46ssqeGh8ZNScWQxqbwg5RNvLAwVw3i5dQcZ3a1h9nRyr\", \"EOS7PoGq46ssqeGh8ZNScWQxqbwg5RNvLAwVw3i5dQcZ3a1h9nRyr\", \"EOS6KnJPV1mDuS8pYuLucaWzkwbWjGPeJsfQDpqc7NZ4F7zTQh4Wt\", \"2000.000 IQUTXO\", \"0.010 IQUTXO\", $NONCE1, \"test transfer\", \"$SIG1\"]" -p eptestusersb
assert $(bc <<< "$? == 0")
SIG2=$(node ../iqutxo/js/sign.js EOS7PoGq46ssqeGh8ZNScWQxqbwg5RNvLAwVw3i5dQcZ3a1h9nRyr EOS7vr4QpGP7ixUSeumeEahHQ99YDE5jiBucf1B2zhuidHzeni1dD 100000 10 $NONCE2 "increment nonce + different relayer" 5KQRA6BBHEHSbmvio3S9oFfVERvv79XXppmYExMouSBqPkZTD79)
cleos push action iqutxoiqutxo transfer "[\"EOS76Pcyw1Hd7hW8hkZdUE1DQ3UiRtjmAKQ3muKwidRqmaM8iNtDy\", \"EOS7PoGq46ssqeGh8ZNScWQxqbwg5RNvLAwVw3i5dQcZ3a1h9nRyr\", \"EOS7vr4QpGP7ixUSeumeEahHQ99YDE5jiBucf1B2zhuidHzeni1dD\", \"100.000 IQUTXO\", \"0.010 IQUTXO\", $NONCE2, \"increment nonce + different relayer\", \"$SIG2\"]" -p eptestusersc
assert $(bc <<< "$? == 0")
SIG3=$(node ../iqutxo/js/sign.js EOS6KnJPV1mDuS8pYuLucaWzkwbWjGPeJsfQDpqc7NZ4F7zTQh4Wt EOS6HfoynFKZ1Msq1bKNwtSTTpEu8NssYMcgsy6nHqhRp3mz7tNkB 100000 10 $NONCE3 "test transfer" 5HyQUNxE9T83RLiS9HdZeJck5WRqNSSzVztZ3JwYvkYPrG8Ca1U)
cleos push action iqutxoiqutxo transfer "[\"EOS76Pcyw1Hd7hW8hkZdUE1DQ3UiRtjmAKQ3muKwidRqmaM8iNtDy\", \"EOS6KnJPV1mDuS8pYuLucaWzkwbWjGPeJsfQDpqc7NZ4F7zTQh4Wt\", \"EOS6HfoynFKZ1Msq1bKNwtSTTpEu8NssYMcgsy6nHqhRp3mz7tNkB\", \"100.000 IQUTXO\", \"0.010 IQUTXO\", $NONCE3, \"test transfer\", \"$SIG3\"]" -p eptestusersa
assert $(bc <<< "$? == 0")

echo -e "${CYAN}-----------------------FAILED UTXO TRANSFERS-----------------------${NC}"
SIG4=$(node ../iqutxo/js/sign.js EOS7PoGq46ssqeGh8ZNScWQxqbwg5RNvLAwVw3i5dQcZ3a1h9nRyr EOS6KnJPV1mDuS8pYuLucaWzkwbWjGPeJsfQDpqc7NZ4F7zTQh4Wt 2000000 10 $NONCE1 "nonce too small" 5KQRA6BBHEHSbmvio3S9oFfVERvv79XXppmYExMouSBqPkZTD79)
cleos push action iqutxoiqutxo transfer "[\"EOS7PoGq46ssqeGh8ZNScWQxqbwg5RNvLAwVw3i5dQcZ3a1h9nRyr\", \"EOS7PoGq46ssqeGh8ZNScWQxqbwg5RNvLAwVw3i5dQcZ3a1h9nRyr\", \"EOS6KnJPV1mDuS8pYuLucaWzkwbWjGPeJsfQDpqc7NZ4F7zTQh4Wt\", \"2000.000 IQUTXO\", \"0.010 IQUTXO\", $NONCE1, \"nonce too small\", \"$SIG4\"]" -p eptestusersb
assert $(bc <<< "$? == 1")

BALANCE=$(cleos get table iqutxoiqutxo iqutxoiqutxo accounts | jq '.rows[] | select(.publickey == "EOS7PoGq46ssqeGh8ZNScWQxqbwg5RNvLAwVw3i5dQcZ3a1h9nRyr") | .balance' | tr -d '"' | awk '{print $1}')
BALANCE_BITES=$(echo "scale=0;($BALANCE * 1000)/1" | bc)
SIG5=$(node ../iqutxo/js/sign.js EOS7PoGq46ssqeGh8ZNScWQxqbwg5RNvLAwVw3i5dQcZ3a1h9nRyr EOS6KnJPV1mDuS8pYuLucaWzkwbWjGPeJsfQDpqc7NZ4F7zTQh4Wt $BALANCE_BITES 10 $NONCE4 "insufficient balance" 5KQRA6BBHEHSbmvio3S9oFfVERvv79XXppmYExMouSBqPkZTD79)
cleos push action iqutxoiqutxo transfer "[\"EOS7PoGq46ssqeGh8ZNScWQxqbwg5RNvLAwVw3i5dQcZ3a1h9nRyr\", \"EOS7PoGq46ssqeGh8ZNScWQxqbwg5RNvLAwVw3i5dQcZ3a1h9nRyr\", \"EOS6KnJPV1mDuS8pYuLucaWzkwbWjGPeJsfQDpqc7NZ4F7zTQh4Wt\", \"$BALANCE IQUTXO\", \"0.010 IQUTXO\", $NONCE4, \"insufficient balance\", \"$SIG5\"]" -p eptestusersb
assert $(bc <<< "$? == 1")

SIG6=$(node ../iqutxo/js/sign.js EOS7PoGq46ssqeGh8ZNScWQxqbwg5RNvLAwVw3i5dQcZ3a1h9nRyr EOS6KnJPV1mDuS8pYuLucaWzkwbWjGPeJsfQDpqc7NZ4F7zTQh4Wt 20000 $BALANCE_BITES $NONCE4 "too high fee" 5KQRA6BBHEHSbmvio3S9oFfVERvv79XXppmYExMouSBqPkZTD79)
cleos push action iqutxoiqutxo transfer "[\"EOS7PoGq46ssqeGh8ZNScWQxqbwg5RNvLAwVw3i5dQcZ3a1h9nRyr\", \"EOS7PoGq46ssqeGh8ZNScWQxqbwg5RNvLAwVw3i5dQcZ3a1h9nRyr\", \"EOS6KnJPV1mDuS8pYuLucaWzkwbWjGPeJsfQDpqc7NZ4F7zTQh4Wt\", \"20.000 IQUTXO\", \"$BALANCE IQUTXO\", $NONCE4, \"too high fee\", \"$SIG6\"]" -p eptestusersb
assert $(bc <<< "$? == 1")

echo -e "${CYAN}-----------------------UTXO WITHDRAWAL-----------------------${NC}"
SIG7=$(node ../iqutxo/js/sign.js EOS7PoGq46ssqeGh8ZNScWQxqbwg5RNvLAwVw3i5dQcZ3a1h9nRyr EOS1111111111111111111111111111111114T1Anm 20000 10 $NONCE5 "eptestusersa" 5KQRA6BBHEHSbmvio3S9oFfVERvv79XXppmYExMouSBqPkZTD79)
cleos push action iqutxoiqutxo transfer "[\"EOS7PoGq46ssqeGh8ZNScWQxqbwg5RNvLAwVw3i5dQcZ3a1h9nRyr\", \"EOS7PoGq46ssqeGh8ZNScWQxqbwg5RNvLAwVw3i5dQcZ3a1h9nRyr\", \"EOS1111111111111111111111111111111114T1Anm\", \"20.000 IQUTXO\", \"0.010 IQUTXO\", $NONCE5, \"eptestusersa\", \"$SIG7\"]" -p eptestusersb
assert $(bc <<< "$? == 0")

echo -e "${CYAN}-----------------------BAD UTXO WITHDRAWALS-----------------------${NC}"
SIG8=$(node ../iqutxo/js/sign.js EOS7PoGq46ssqeGh8ZNScWQxqbwg5RNvLAwVw3i5dQcZ3a1h9nRyr EOS1111111111111111111111111111111114T1Anm $BALANCE_BITES 10 $NONCE6 "eptestusersa" 5KQRA6BBHEHSbmvio3S9oFfVERvv79XXppmYExMouSBqPkZTD79)
cleos push action iqutxoiqutxo transfer "[\"EOS7PoGq46ssqeGh8ZNScWQxqbwg5RNvLAwVw3i5dQcZ3a1h9nRyr\", \"EOS7PoGq46ssqeGh8ZNScWQxqbwg5RNvLAwVw3i5dQcZ3a1h9nRyr\", \"EOS1111111111111111111111111111111114T1Anm\", \"$BALANCE IQUTXO\", \"0.010 IQUTXO\", $NONCE6, \"eptestusersa\", \"$SIG8\"]" -p eptestusersb
assert $(bc <<< "$? == 1")
# non-existent to account
SIG9=$(node ../iqutxo/js/sign.js EOS7PoGq46ssqeGh8ZNScWQxqbwg5RNvLAwVw3i5dQcZ3a1h9nRyr EOS1111111111111111111111111111111114T1Anm 20000 10 $NONCE6 "tensmensdens" 5KQRA6BBHEHSbmvio3S9oFfVERvv79XXppmYExMouSBqPkZTD79)
cleos push action iqutxoiqutxo transfer "[\"EOS7PoGq46ssqeGh8ZNScWQxqbwg5RNvLAwVw3i5dQcZ3a1h9nRyr\", \"EOS7PoGq46ssqeGh8ZNScWQxqbwg5RNvLAwVw3i5dQcZ3a1h9nRyr\", \"EOS1111111111111111111111111111111114T1Anm\", \"20.000 IQUTXO\", \"0.010 IQUTXO\", $NONCE6, \"tensmensdens\", \"$SIG9\"]" -p eptestusersb
assert $(bc <<< "$? == 1")
# nonsensincally long memo
SIG10=$(node ../iqutxo/js/sign.js EOS7PoGq46ssqeGh8ZNScWQxqbwg5RNvLAwVw3i5dQcZ3a1h9nRyr EOS1111111111111111111111111111111114T1Anm 20000 10 $NONCE6 "gumberbalderdash" 5KQRA6BBHEHSbmvio3S9oFfVERvv79XXppmYExMouSBqPkZTD79)
cleos push action iqutxoiqutxo transfer "[\"EOS7PoGq46ssqeGh8ZNScWQxqbwg5RNvLAwVw3i5dQcZ3a1h9nRyr\", \"EOS7PoGq46ssqeGh8ZNScWQxqbwg5RNvLAwVw3i5dQcZ3a1h9nRyr\", \"EOS1111111111111111111111111111111114T1Anm\", \"20.000 IQUTXO\", \"0.010 IQUTXO\", $NONCE6, \"gumberbalderdash\", \"$SIG10\"]" -p eptestusersb
assert $(bc <<< "$? == 1")

echo -e "${CYAN}-----------------------CHECK RESERVE AND BALANCES-----------------------${NC}"
SUM_BALANCES=$(cleos get table iqutxoiqutxo iqutxoiqutxo accounts | jq ".rows[].balance" | tr -d '"' | awk '{print $1}' | paste -sd+ | bc)
SUPPLY=$(cleos get table iqutxoiqutxo 22333642392029443 stats | jq ".rows[0].supply" | tr -d '"' | awk '{print $1}')
RESERVE=$(cleos get table everipediaiq iqutxoiqutxo accounts | jq ".rows[0].balance" | tr -d '"' | awk '{print $1}')
echo -e "   ${CYAN}SUM_BALANCES: $SUM_BALANCES${NC}"
echo -e "   ${CYAN}SUPPLY: $SUM_BALANCES${NC}"
echo -e "   ${CYAN}RESERVE: $SUM_BALANCES${NC}"
assert $(bc <<< "$SUM_BALANCES == $SUPPLY")
assert $(bc <<< "$SUM_BALANCES == $RESERVE")

# Burns
echo -e "${CYAN}-----------------------TESTING BURNS-----------------------${NC}"
OLD_SUPPLY=$(cleos get table everipediaiq IQ stat | jq ".rows[0].supply" | tr -d '"' | awk '{print $1}')
OLD_BALANCE6=$(balance eptestusersf)
OLD_BALANCE7=$(balance eptestusersg)

cleos push action everipediaiq burn '["eptestusersg", "1000.000 IQ", "test"]' -p eptestusersg
assert $(bc <<< "$? == 0")
cleos push action everipediaiq burn '["eptestusersf", "1000.000 IQ", "test"]' -p eptestusersf
assert $(bc <<< "$? == 0")

NEW_BALANCE6=$(balance eptestusersf)
NEW_BALANCE7=$(balance eptestusersg)
NEW_SUPPLY=$(cleos get table everipediaiq IQ stat | jq ".rows[0].supply" | tr -d '"' | awk '{print $1}')

assert $(bc <<< "$OLD_BALANCE6 - $NEW_BALANCE6 == 1000")
assert $(bc <<< "$OLD_BALANCE7 - $NEW_BALANCE7 == 1000")
assert $(bc <<< "$OLD_SUPPLY - $NEW_SUPPLY == 2000")

# Failed burns
echo -e "${CYAN}-----------------------FAILED BURNS-----------------------${NC}"
cleos push action everipediaiq burn '["eptestusersg", "1000.000 IQ", "test"]' -p eptestusersf
assert $(bc <<< "$? == 1")
cleos push action everipediaiq burn '["eptestusersf", "10000000.000 IQ", "test"]' -p eptestusersf
assert $(bc <<< "$? == 1")

# Proposals
echo -e "${CYAN}-----------------------TEST PROPOSALS-----------------------${NC}"
IPFS1=$(ipfsgen)
IPFS2=$(ipfsgen)
IPFS3=$(ipfsgen)
IPFS4=$(ipfsgen)
IPFS5=$(ipfsgen)
IPFS6=$(ipfsgen)
IPFS7=$(ipfsgen)
IPFS8=$(ipfsgen)

SLUG1=$(titlegen)
SLUG2=$(titlegen)
SLUG3=$(titlegen)
SLUG4=$(titlegen)
SLUG5=$(titlegen)
SLUG6=$(titlegen)
SLUG7=$(titlegen)
SLUG8=$(titlegen)

cleos push action everipediaiq epartpropose "[ \"eptestusersa\", \"$SLUG1\", \"$IPFS1\", \"en\", -1, \"new wiki\", \"memoing\", "active" ]" -p eptestusersa
assert $(bc <<< "$? == 0")
cleos push action everipediaiq epartpropose "[ \"eptestusersb\", \"$SLUG2\", \"$IPFS2\", \"kr\", -1, \"new wiki\", \"memoing\", "active" ]" -p eptestusersb
assert $(bc <<< "$? == 0")
cleos push action everipediaiq epartpropose "[ \"eptestusersc\", \"$SLUG3\", \"$IPFS3\", \"zh-Hans\", -1, \"new wiki\", \"memoing\", "active" ]" -p eptestusersc
assert $(bc <<< "$? == 0")
cleos push action everipediaiq epartpropose "[ \"eptestusersd\", \"$SLUG4\", \"$IPFS4\", \"en\", 2, \"new wiki. existing group\", \"memoing\", "active" ]" -p eptestusersd
assert $(bc <<< "$? == 0")
cleos push action everipediaiq epartpropose "[ \"eptestusersf\", \"$SLUG1\", \"$IPFS1\", \"kr\", 0, \"update lang code\", \"memoing\", "active" ]" -p eptestusersf
assert $(bc <<< "$? == 0")
cleos push action everipediaiq epartpropose "[ \"eptestusersf\", \"$SLUG2\", \"$IPFS5\", \"kr\", 5, \"update hash\", \"memoing\", "active" ]" -p eptestusersf
assert $(bc <<< "$? == 0")

# Failed proposals
echo -e "${CYAN}-----------------------NEXT SET OF PROPOSALS SHOULD FAIL-----------------------${NC}"
cleos push action everipediaiq epartpropose "[ \"eptestusersf\", \"7-Dwarfs-of Christmas-have-too-long-a-title-matesssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss\", \"$IPFS1\", \"en\", -1, \"commenting\", \"memoing\" ]" -p eptestusersf
assert $(bc <<< "$? == 1")
cleos push action everipediaiq epartpropose "[ \"eptestusersf\", \"$SLUG8\", \"$IPFS1\", \"en\", -2, \"specifying a group ID below -1\", \"memoing\", "active" ]" -p eptestusersf
assert $(bc <<< "$? == 1")
cleos push action everipediaiq epartpropose "[ \"eptestusersf\", \"$SLUG8\", \"$IPFS1\", \"zh-Hans 02\", -1, \"too long a lang code\", \"memoing\", "active" ]" -p eptestusersf
assert $(bc <<< "$? == 1")
cleos push action everipediaiq epartpropose "[ \"eptestusersf\", \"$SLUG8\", \"$IPFS2 $IPFS1\", \"zh\", -1, \"too long an IPFS string\", \"memoing\", "active" ]" -p eptestusersf
assert $(bc <<< "$? == 1")
cleos push action everipediaiq epartpropose "[ \"eptestuserse\", \"$SLUG8\", \"$IPFS6\", \"en\", 100038, \"wrong authorization\", \"memoing\", "active" ]" -p eptestusersf
assert $(bc <<< "$? == 1")
cleos push action everipediaiq epartpropose "[ \"eptestuserse\", \"\", \"$IPFS6\", \"en\", 100038, \"empty slug\", \"memoing\", "active" ]" -p eptestuserse
assert $(bc <<< "$? == 1")

echo -e "${CYAN}Wait for proposals to be mined...${NC}"
sleep 1

# Votes
PROPS=$(cleos get table eparticlectr eparticlectr propstbl2 -r | jq ".rows")
PROPID6=$(echo $PROPS | jq ".[0].id")
PROPID5=$(echo $PROPS | jq ".[1].id")
PROPID4=$(echo $PROPS | jq ".[2].id")
PROPID3=$(echo $PROPS | jq ".[3].id")
PROPID2=$(echo $PROPS | jq ".[4].id")
PROPID1=$(echo $PROPS | jq ".[5].id")

# Win
echo -e "${CYAN}-----------------------SETTING WINNING VOTES-----------------------${NC}"
cleos push action everipediaiq epartvote "[ \"eptestusersb\", $PROPID1, 1, 50, \"vote comment\", \"votememo\", "active"]" -p eptestusersb
assert $(bc <<< "$? == 0")
cleos push action everipediaiq epartvote "[ \"eptestusersc\", $PROPID1, 1, 100,\"vote comment\",  \"votememo\", "active"]" -p eptestusersc
assert $(bc <<< "$? == 0")
cleos push action everipediaiq epartvote "[ \"eptestusersd\", $PROPID1, 0, 50, \"vote comment\", \"votememo\", "active"]" -p eptestusersd
assert $(bc <<< "$? == 0")
cleos push action everipediaiq epartvote "[ \"eptestuserse\", $PROPID1, 1, 500,\"vote comment\",  \"votememo\", "active"]" -p eptestuserse
assert $(bc <<< "$? == 0")
cleos push action everipediaiq epartvote "[ \"eptestusersf\", $PROPID1, 0, 350,\"vote comment\",  \"votememo\", "active"]" -p eptestusersf
assert $(bc <<< "$? == 0")
cleos push action everipediaiq epartvote "[ \"eptestusersg\", $PROPID1, 0, 80, \"vote comment\", \"votememo\", "active"]" -p eptestusersg
assert $(bc <<< "$? == 0")

# Lose
echo -e "${CYAN}-----------------------SETTING LOSING VOTES-----------------------${NC}"
cleos push action everipediaiq epartvote "[ \"eptestusersb\", $PROPID2, 1, 5, \"vote comment\", \"votememo\", "active"]" -p eptestusersb
assert $(bc <<< "$? == 0")
cleos push action everipediaiq epartvote "[ \"eptestusersc\", $PROPID2, 0, 100, \"vote comment\", \"votememo\", "active"]" -p eptestusersc
assert $(bc <<< "$? == 0")
cleos push action everipediaiq epartvote "[ \"eptestusersd\", $PROPID2, 1, 500, \"vote comment\", \"votememo\", "active"]" -p eptestusersd
assert $(bc <<< "$? == 0")
cleos push action everipediaiq epartvote "[ \"eptestuserse\", $PROPID2, 0, 500, \"vote comment\", \"votememo\", "active"]" -p eptestuserse
assert $(bc <<< "$? == 0")
cleos push action everipediaiq epartvote "[ \"eptestusersf\", $PROPID2, 1, 35, \"vote comment\", \"votememo\", "active"]" -p eptestusersf
assert $(bc <<< "$? == 0")
cleos push action everipediaiq epartvote "[ \"eptestusersg\", $PROPID2, 0, 800, \"vote comment\", \"votememo\", "active"]" -p eptestusersg
assert $(bc <<< "$? == 0")

# Tie (net votes dont't sum to 0 because proposer auto-votes 50 in favor)
echo -e "${CYAN}-----------------------SETTING TIE VOTES-----------------------${NC}"
cleos push action everipediaiq epartvote "[ \"eptestusersb\", $PROPID3, 1, 15, \"vote comment\", \"votememo\", "active"]" -p eptestusersb
assert $(bc <<< "$? == 0")
cleos push action everipediaiq epartvote "[ \"eptestusersc\", $PROPID3, 0, 150,\"vote comment\", \"votememo\", "active"]" -p eptestusersc
assert $(bc <<< "$? == 0")
cleos push action everipediaiq epartvote "[ \"eptestusersd\", $PROPID3, 1, 490,\"vote comment\", \"votememo\", "active"]" -p eptestusersd
assert $(bc <<< "$? == 0")
cleos push action everipediaiq epartvote "[ \"eptestuserse\", $PROPID3, 0, 500,\"vote comment\", \"votememo\", "active"]" -p eptestuserse
assert $(bc <<< "$? == 0")
cleos push action everipediaiq epartvote "[ \"eptestusersf\", $PROPID3, 1, 35, \"vote comment\", \"votememo\", "active"]" -p eptestusersf
assert $(bc <<< "$? == 0")
cleos push action everipediaiq epartvote "[ \"eptestusersg\", $PROPID3, 1, 60, \"vote comment\", \"votememo\", "active"]" -p eptestusersg
assert $(bc <<< "$? == 0")

# Unanimous win
echo -e "${CYAN}-----------------------UNANIMOUS VOTES-----------------------${NC}"
cleos push action everipediaiq epartvote "[ \"eptestusersb\", $PROPID4, 1, 5, \"vote comment\", \"votememo\", "active"]" -p eptestusersb
assert $(bc <<< "$? == 0")
cleos push action everipediaiq epartvote "[ \"eptestusersc\", $PROPID4, 1, 10,\"vote comment\", \"votememo\", "active"]" -p eptestusersc
assert $(bc <<< "$? == 0")
cleos push action everipediaiq epartvote "[ \"eptestusersd\", $PROPID4, 1, 50,\"vote comment\", \"votememo\", "active"]" -p eptestusersd
assert $(bc <<< "$? == 0")
cleos push action everipediaiq epartvote "[ \"eptestuserse\", $PROPID4, 1, 50,\"vote comment\", \"votememo\", "active"]" -p eptestuserse
assert $(bc <<< "$? == 0")
cleos push action everipediaiq epartvote "[ \"eptestusersf\", $PROPID4, 1, 35,\"vote comment\", \"votememo\", "active"]" -p eptestusersf
assert $(bc <<< "$? == 0")
cleos push action everipediaiq epartvote "[ \"eptestusersg\", $PROPID4, 1, 60,\"vote comment\", \"votememo\", "active"]" -p eptestusersg
assert $(bc <<< "$? == 0")

# User votes against himself
echo -e "${CYAN}-----------------------USER VOTES AGAINST HIMSELF-----------------------${NC}"
cleos push action everipediaiq epartvote "[ \"eptestuserse\", $PROPID5, 0, 60, \"vote comment\", \"votememo\", "active"]" -p eptestuserse
assert $(bc <<< "$? == 0")

# Bad votes
echo -e "${CYAN}-----------------------NEXT TWO VOTE ATTEMPTS SHOULD FAIL-----------------------${NC}"
cleos push action everipediaiq epartvote "[ \"eptestusersg\", $PROPID4, 1, 500000000, \"vote comment\", \"votememo\", "active"]" -p eptestusersg
assert $(bc <<< "$? == 1")
cleos push action everipediaiq epartvote "[ \"eptestusersc\", $PROPID4, 1, 500, \"vote comment\", \"votememo\", "active"]" -p eptestusersg
assert $(bc <<< "$? == 1")


# Finalize
echo -e "${CYAN}-----------------------EARLY FINALIZE SHOULD FAIL-----------------------${NC}"
cleos push action eparticlectr finalize "[ $PROPID4 ]" -p eptestuserse
assert $(bc <<< "$? == 1")

echo -e "${CYAN}WAITING FOR VOTING PERIOD TO END...${NC}"
sleep 4 # wait for test voting period to end

# Bad vote
echo -e "${CYAN}-----------------------LATE VOTE SHOULD FAIL-----------------------${NC}"
cleos push action everipediaiq epartvote "[ \"eptestusersc\", $PROPID4, 1, 500, \"votecomment\", \"votememo\" ]" -p eptestusersc
assert $(bc <<< "$? == 1")

echo -e "${CYAN}-----------------------FINALIZES-----------------------${NC}"
cleos push action eparticlectr finalize "[ $PROPID1 ]" -p eptestusersa
assert $(bc <<< "$? == 0")
cleos push action eparticlectr finalize "[ $PROPID2 ]" -p eptestusersg
assert $(bc <<< "$? == 0")
cleos push action eparticlectr finalize "[ $PROPID3 ]" -p eptestuserse
assert $(bc <<< "$? == 0")
cleos push action eparticlectr finalize "[ $PROPID4 ]" -p eptestusersb
assert $(bc <<< "$? == 0")
cleos push action eparticlectr finalize "[ $PROPID5 ]" -p eptestusersa
assert $(bc <<< "$? == 0")
cleos push action eparticlectr finalize "[ $PROPID6 ]" -p eptestusersc
assert $(bc <<< "$? == 0")

echo -e "${CYAN}-----------------------FINALIZE FAIL (ALREADY FINALIZED)-----------------------${NC}"
cleos push action --force-unique eparticlectr finalize "[ $PROPID3 ]" -p eptestuserse
assert $(bc <<< "$? == 1")

# Procrewards
echo -e "${CYAN}-----------------------EARLY PROCREWARDS SHOULD FAIL-----------------------${NC}"

FINALIZE_PERIOD=$(cleos get table eparticlectr eparticlectr rewardstbl2 -r | jq ".rows[0].proposal_finalize_period")
ONE_BACK_PERIOD=$(bc <<< "$FINALIZE_PERIOD - 1")
ONE_FORWARD_PERIOD=$(bc <<< "$FINALIZE_PERIOD + 1")

cleos push action eparticlectr procrewards "[$ONE_FORWARD_PERIOD]" -p eptestusersa
assert $(bc <<< "$? == 1")

# Slash checks
echo -e "${CYAN}-----------------------TODO: TEST SLASHES-----------------------${NC}"

echo -e "${CYAN}WAITING FOR REWARDS PERIOD TO END...${NC}"
sleep 5


echo -e "${CYAN}-----------------------PROCESS REWARDS-----------------------${NC}"
cleos push action eparticlectr procrewards "[$FINALIZE_PERIOD]" -p eptestusersa
assert $(bc <<< "$? == 0")

CURATION_REWARD_SUM=$(cleos get table eparticlectr eparticlectr perrwdstbl2 -r | jq ".rows[0].curation_sum")
EDITOR_REWARD_SUM=$(cleos get table eparticlectr eparticlectr perrwdstbl2 -r | jq ".rows[0].editor_sum")

echo -e "   ${CYAN}CURATION REWARD SUM: ${CURATION_REWARD_SUM}${NC}"
echo -e "   ${CYAN}EDITOR REWARD SUM: ${EDITOR_REWARD_SUM}${NC}"

assert $(bc <<< "$CURATION_REWARD_SUM == 2470")
assert $(bc <<< "$EDITOR_REWARD_SUM == 530")

# Claim rewards
OLD_BALANCE4=$(balance eptestusersd)
OLD_BALANCE5=$(balance eptestuserse)
OLD_BALANCE6=$(balance eptestusersf)
OLD_BALANCE7=$(balance eptestusersg)

REWARD_ID1=$(cleos get table eparticlectr eparticlectr rewardstbl2 -r | jq ".rows[0].id")
REWARD_ID2=$(bc <<< "$REWARD_ID1 - 2")
REWARD_ID3=$(bc <<< "$REWARD_ID1 - 3")
REWARD_ID4=$(bc <<< "$REWARD_ID1 - 4")
REWARD_ID5=$(bc <<< "$REWARD_ID1 - 8") # this one has edit points

echo -e "${CYAN}-----------------------CLAIM REWARDS-----------------------${NC}"
cleos push action eparticlectr rewardclmid "[\"$REWARD_ID1\"]" -p eptestuserse
assert $(bc <<< "$? == 0")
cleos push action eparticlectr rewardclmid "[\"$REWARD_ID2\"]" -p eptestusersg
assert $(bc <<< "$? == 0")
cleos push action eparticlectr rewardclmid "[\"$REWARD_ID3\"]" -p eptestusersf
assert $(bc <<< "$? == 0")
cleos push action eparticlectr rewardclmid "[\"$REWARD_ID4\"]" -p eptestuserse
assert $(bc <<< "$? == 0")
cleos push action eparticlectr rewardclmid "[\"$REWARD_ID5\"]" -p eptestusersd
assert $(bc <<< "$? == 0")

NEW_BALANCE4=$(balance eptestusersd)
NEW_BALANCE5=$(balance eptestuserse)
NEW_BALANCE6=$(balance eptestusersf)
NEW_BALANCE7=$(balance eptestusersg)

DIFF4=$(bc <<< "$NEW_BALANCE4 - $OLD_BALANCE4")
DIFF5=$(bc <<< "$NEW_BALANCE5 - $OLD_BALANCE5")
DIFF6=$(bc <<< "$NEW_BALANCE6 - $OLD_BALANCE6")
DIFF7=$(bc <<< "$NEW_BALANCE7 - $OLD_BALANCE7")

echo -e "${CYAN}REWARDS:${NC}"
echo -e "${CYAN}    eptestusersd: $DIFF4${NC}"
echo -e "${CYAN}    eptestuserse: $DIFF5${NC}"
echo -e "${CYAN}    eptestusersf: $DIFF6${NC}"
echo -e "${CYAN}    eptestusersg: $DIFF7${NC}"

assert $(bc <<< "$DIFF4 == 198.250")
assert $(bc <<< "$DIFF5 == 2.024")
assert $(bc <<< "$DIFF6 == 41.176")
assert $(bc <<< "$DIFF7 == 2.429")

echo -e "${CYAN}-----------------------NEXT TWO CLAIMS SHOULD FAIL-----------------------${NC}"
cleos push action --force-unique eparticlectr rewardclmid "[\"$REWARD_ID3\"]" -p eptestusersf
assert $(bc <<< "$? != 0")
cleos push action --force-unique eparticlectr rewardclmid "[3249293423]" -p eptestusersf
assert $(bc <<< "$? != 0")

echo -e "${CYAN}-----------------------VOTE PURGES BELOW SHOULD PASS-----------------------${NC}"
cleos push action eparticlectr oldvotepurge "[$PROPID1, 100]" -p eptestusersa
assert $(bc <<< "$? == 0")
cleos push action eparticlectr oldvotepurge "[$PROPID2, 100]" -p eptestusersa
assert $(bc <<< "$? == 0")
cleos push action eparticlectr oldvotepurge "[$PROPID3, 2]" -p eptestusersa
assert $(bc <<< "$? == 0")
cleos push action eparticlectr oldvotepurge "[$PROPID4, 5]" -p eptestusersa
assert $(bc <<< "$? == 0")

echo -e "${CYAN}-----------------------NEXT THREE VOTE PURGES SHOULD FAIL-----------------------${NC}"
cleos push action eparticlectr oldvotepurge "[\"$IPFS1\", 100]" -p eptestusersa
assert $(bc <<< "$? == 1")
cleos push action eparticlectr oldvotepurge '["gumdrop", 100]' -p eptestusersa
assert $(bc <<< "$? == 1")
# Cannot delete newest proposal
cleos push action eparticlectr oldvotepurge "[$PROPID6, 100]" -p eptestusersa
assert $(bc <<< "$? == 1")

echo -e "${CYAN}-----------------------BELOW CLAIMS SHOULD PASS-----------------------${NC}"
STAKE_ID1=$(cleos get table eparticlectr eparticlectr staketbl2 -r | jq ".rows[0].id")
STAKE_ID2=$(bc <<< "$STAKE_ID1 - 1")
STAKE_ID3=$(bc <<< "$STAKE_ID1 - 2")
STAKE_ID4=$(bc <<< "$STAKE_ID1 - 3")

cleos push action eparticlectr brainclmid "[$STAKE_ID1]" -p eptestusersa
assert $(bc <<< "$? == 0")
cleos push action eparticlectr brainclmid "[$STAKE_ID2]" -p eptestusersg
assert $(bc <<< "$? == 0")
cleos push action eparticlectr brainclmid "[$STAKE_ID3]" -p eptestusersb
assert $(bc <<< "$? == 0")
cleos push action eparticlectr brainclmid "[$STAKE_ID4]" -p eptestuserse
assert $(bc <<< "$? == 0")

echo -e "${CYAN}-----------------------THIS CLAIM SHOULD FAIL-----------------------${NC}"
cleos push action eparticlectr brainclmid "[$STAKE_ID1]" -p eptestusersf
assert $(bc <<< "$? == 1")

echo -e "${CYAN}-----------------------MAKE ANOTHER PROPOSAL THEN DELETE THE PREVIOUS ONE-----------------------${NC}"
cleos push action everipediaiq epartpropose "[ \"eptestusersa\", \"$SLUG8\", \"$IPFS4\", \"en\", -1, \"new wiki\", \"memoing\", "active" ]" -p eptestusersa
assert $(bc <<< "$? == 0")
cleos push action eparticlectr oldvotepurge "[$PROPID6, 100]" -p eptestusersa
assert $(bc <<< "$? == 0")

echo -e "${CYAN}-----------------------COMPLETE-----------------------${NC}"

import os
import logging
from typing import Optional

logger = logging.getLogger(__name__)

RPC_URL = os.getenv("BLOCKCHAIN_RPC_URL", "")
CONTRACT_ADDRESS = os.getenv("CONTRACT_ADDRESS", "")
PRIVATE_KEY = os.getenv("BLOCKCHAIN_PRIVATE_KEY", "")

CONTRACT_ABI = [
    {
        "anonymous": False,
        "inputs": [
            {"indexed": False, "internalType": "string", "name": "documentId", "type": "string"},
            {"indexed": False, "internalType": "bytes32", "name": "documentHash", "type": "bytes32"},
            {"indexed": False, "internalType": "uint256", "name": "timestamp", "type": "uint256"},
            {"indexed": False, "internalType": "string", "name": "uploader", "type": "string"}
        ],
        "name": "DocumentStored",
        "type": "event"
    },
    {
        "inputs": [{"internalType": "string", "name": "", "type": "string"}],
        "name": "documents",
        "outputs": [
            {"internalType": "bytes32", "name": "documentHash", "type": "bytes32"},
            {"internalType": "uint256", "name": "timestamp", "type": "uint256"},
            {"internalType": "string", "name": "uploader", "type": "string"}
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [
            {"internalType": "string", "name": "documentId", "type": "string"},
            {"internalType": "string", "name": "uploader", "type": "string"},
            {"internalType": "bytes32", "name": "documentHash", "type": "bytes32"}
        ],
        "name": "storeDocument",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [
            {"internalType": "string", "name": "documentId", "type": "string"},
            {"internalType": "bytes32", "name": "documentHash", "type": "bytes32"}
        ],
        "name": "verifyDocument",
        "outputs": [{"internalType": "bool", "name": "", "type": "bool"}],
        "stateMutability": "view",
        "type": "function"
    }
]


def _get_contract():
    if not RPC_URL or not CONTRACT_ADDRESS:
        return None, None
    try:
        from web3 import Web3
        w3 = Web3(Web3.HTTPProvider(RPC_URL))
        contract = w3.eth.contract(
            address=Web3.to_checksum_address(CONTRACT_ADDRESS),
            abi=CONTRACT_ABI
        )
        return w3, contract
    except Exception as e:
        logger.warning(f"Blockchain connection failed: {e}")
        return None, None


def store_document_hash(doc_id: str, uploader: str, file_hash: str) -> Optional[str]:
    """
    Call storeDocument() on-chain. Returns tx hash string or None if not configured.
    file_hash must be a 64-char hex string (SHA-256).
    """
    print(f"[blockchain] store_document_hash called for doc_id={doc_id[:12]}...")

    w3, contract = _get_contract()
    if not w3 or not contract or not PRIVATE_KEY:
        print(
            f"[blockchain] SKIPPED — w3={w3 is not None}, "
            f"contract={contract is not None}, key_set={bool(PRIVATE_KEY)}"
        )
        return None

    try:
        hash_bytes = bytes.fromhex(file_hash)
        account = w3.eth.account.from_key(PRIVATE_KEY)
        balance_wei = w3.eth.get_balance(account.address)
        print(
            f"[blockchain] wallet={account.address} "
            f"balance={w3.from_wei(balance_wei, 'ether')} ETH"
        )

        tx = contract.functions.storeDocument(
            doc_id, uploader, hash_bytes
        ).build_transaction({
            "from": account.address,
            "nonce": w3.eth.get_transaction_count(account.address),
            "gas": 200000,
            "gasPrice": w3.eth.gas_price,
        })

        signed = w3.eth.account.sign_transaction(tx, PRIVATE_KEY)
        tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
        tx_hex = tx_hash.hex()
        print(f"[blockchain] ✅ storeDocument tx: {tx_hex}")
        print(f"[blockchain]    https://sepolia.etherscan.io/tx/{tx_hex}")
        return tx_hex
    except Exception as e:
        print(f"[blockchain] ❌ storeDocument failed: {type(e).__name__}: {e}")
        return None


def verify_document_hash(doc_id: str, file_hash: str) -> bool:
    """Call verifyDocument() on-chain. Returns True if hash matches."""
    w3, contract = _get_contract()
    if not w3 or not contract:
        return False

    try:
        hash_bytes = bytes.fromhex(file_hash)
        return contract.functions.verifyDocument(doc_id, hash_bytes).call()
    except Exception as e:
        logger.error(f"verifyDocument failed: {e}")
        return False

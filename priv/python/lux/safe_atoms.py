"""
Safe atoms list and helpers for Lux Python integration.

This module contains a curated list of safe atoms that can be used when converting
Python dictionaries to Elixir structs. This prevents atom table exhaustion by
limiting which strings can be converted to atoms.
"""

from erlport.erlterms import Atom

# Predefined set of safe atoms that can be used for struct fields
SAFE_ATOMS = {
    # Core struct fields
    '__struct__',
    'name',
    'id',
    'type',
    'value',
    'data',
    'metadata',
    'status',
    
    # Common fields
    'created_at',
    'updated_at',
    'deleted_at',
    'description',
    'title',
    'content',
    'url',
    'email',
    'password',
    'role',
    'permissions',
    'settings',
    'config',
    'options',
    
    # Relationship fields
    'user_id',
    'parent_id',
    'owner',
    'group',
    
    # State fields
    'enabled',
    'active',
    'locked',
    'visible',
    'public',
    'private',
    'shared',
    
    # Error handling
    'errors',
    'warnings',
    'messages',
    'success',
    'error',
    'message',
    'code',
    
    # Common attributes
    'category',
    'customer',
    'format',
    'items',
    'language',
    'locale',
    'priority',
    'result',
    'score',
    'scores',
    'source',
    'state',
    'tags',
    'target',
    'timezone',
    'version',
    'amount',
    'currency',
    'price',
    'quantity',
    'total',
    'subtotal',
    'tax',
    'discount',
    'shipping',
    'handling',

    # Letters
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',

    # Web3 and Crypto
    # Blockchain
    'chain_id',
    'network',
    'mainnet',
    'testnet',
    'block_number',
    'block_hash',
    'block_timestamp',
    'gas_price',
    'gas_limit',
    'gas_used',
    'nonce',
    'confirmations',
    
    # Transactions
    'tx_hash',
    'transaction_hash',
    'from_address',
    'to_address',
    'value',
    'input_data',
    'signature',
    'signed',
    'pending',
    'confirmed',
    'failed',
    'reverted',
    'receipt',
    
    # Accounts and Wallets
    'address',
    'private_key',
    'public_key',
    'mnemonic',
    'seed_phrase',
    'derivation_path',
    'wallet',
    'account',
    'balance',
    'allowance',
    
    # Smart Contracts
    'contract_address',
    'contract_name',
    'abi',
    'bytecode',
    'deployed',
    'verified',
    'owner',
    'implementation',
    'proxy',
    'delegate',
    'upgradeable',
    
    # Tokens
    'token_address',
    'token_id',
    'token_uri',
    'token_type',
    'symbol',
    'decimals',
    'total_supply',
    'max_supply',
    'circulating_supply',
    'holders',
    'transfers',
    'approvals',
    
    # NFTs
    'collection',
    'asset_id',
    'metadata_uri',
    'attributes',
    'rarity',
    'mint_price',
    'mint_date',
    'mint_status',
    'royalties',
    'creator',
    'owner_history',
    
    # DeFi
    'pool',
    'pair',
    'liquidity',
    'reserves',
    'swap',
    'stake',
    'unstake',
    'yield',
    'apy',
    'apr',
    'rewards',
    'farm',
    'harvest',
    'collateral',
    'debt',
    'borrow',
    'lend',
    'repay',
    'liquidate',
    
    # Governance
    'proposal',
    'vote',
    'quorum',
    'delegation',
    'snapshot',
    'voting_power',
    'timelock',
    'executor',
    'dao',
    
    # Protocol-specific
    'erc20',
    'erc721',
    'erc1155',
    'uniswap',
    'sushiswap',
    'compound',
    'aave',
    'maker',
    'chainlink',
    'oracle',
    'price_feed',
    
    # Consensus and Network
    'consensus',
    'pow',
    'pos',
    'validator',
    'node',
    'peer',
    'sync_status',
    'network_id',
    'rpc_url',
    'websocket',
    
    # Security
    'signature_type',
    'signed_message',
    'recovered_address',
    'merkle_root',
    'merkle_proof',
    'whitelist',
    'blacklist',
    'paused',
    'frozen',
    
    # Events and Logs
    'event_name',
    'event_signature',
    'log_index',
    'topics',
    'data',
    'indexed',
    'filters',
    'subscription',
    
    # Layer 2 and Scaling
    'l2',
    'rollup',
    'optimistic',
    'zk',
    'bridge',
    'channel',
    'state',
    'batch',
    'proof',
    'commitment',
    
    # IPFS and Storage
    'ipfs_hash',
    'cid',
    'pinned',
    'storage_provider',
    'arweave',
    'filecoin',
    
    # Misc Web3
    'web3',
    'provider',
    'signer',
    'chain',
    'network',
    'explorer_url',
    'fiat_value',
    'gas_token',
}

class UnsafeAtomError(Exception):
    """Raised when attempting to convert an unsafe string to an atom."""
    pass

def safe_atom(name):
    """Convert a string to an atom only if it's in the SAFE_ATOMS set.
    
    Args:
        name (str): The string to convert to an atom
        
    Returns:
        Atom: If the name is in SAFE_ATOMS
        bytes: If the name is not in SAFE_ATOMS, returns it as a binary string
        
    Raises:
        UnsafeAtomError: If strict mode is enabled and name is not in SAFE_ATOMS
    """
    if name in SAFE_ATOMS:
        return Atom(name.encode('utf-8'))
    raise UnsafeAtomError(f"Attempted to create unsafe atom: {name}")

def safe_struct_keys(struct_dict):
    """Convert all keys in a struct dictionary to atoms if they are safe.
    
    Args:
        struct_dict (dict): Dictionary to convert keys for
        
    Returns:
        dict: New dictionary with safe atom keys
        
    Raises:
        UnsafeAtomError: If any key is not in SAFE_ATOMS
    """
    return {safe_atom(k): v for k, v in struct_dict.items()} 
# Create fund to the wallet
# @param [Glueby::Internal::Wallet] wallet
def fund_to_wallet(wallet, color_id: Tapyrus::Color::ColorIdentifier.default)
  ar_wallet = Glueby::Internal::Wallet::AR::Wallet.find_by(wallet_id: wallet.id)
  ar_key = ar_wallet.keys.create!(purpose: :receive)
  txid = Tapyrus::sha256(wallet.id + color_id.to_hex).bth # dummy txid

  script_pubkey = if color_id.default?
                    valid_script_pubkey
                  else
                    valid_script_pubkey.add_color(color_id)
                  end

  20.times do |i|
    Glueby::Internal::Wallet::AR::Utxo.create!(
      txid: txid,
      index: i,
      script_pubkey: script_pubkey.to_hex,
      key: ar_key,
      value: 1_000,
      status: :finalized
    )
  end
end
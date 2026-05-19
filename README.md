This is part of Thecore framework: https://github.com/gabrieletassoni/thecore/tree/release/3

## Invio email e configurazione SMTP

### Configurazione

Le impostazioni SMTP sono salvate in `ThecoreSettings` (namespace `:smtp`) e vengono caricate automaticamente dai seeds del gem:

| Chiave              | Descrizione                                                                 |
| ------------------- | --------------------------------------------------------------------------- |
| `address`           | Indirizzo del server SMTP (obbligatorio per abilitare la consegna)          |
| `port`              | Porta (default `587`); impostare `465` per SMTPS (SSL implicito)           |
| `domain`            | Dominio HELO                                                                |
| `user_name`         | Username per l'autenticazione                                               |
| `password`          | Password per l'autenticazione                                               |
| `authentication`    | `plain`, `login`, `cram_md5`, oppure `none`/vuoto per disabilitare l'auth  |
| `enable_starttls_auto` | Impostare a `false`, `f`, `0` o `no` per disabilitare STARTTLS. Ignorato se `port` è `465` (SMTPS usa TLS implicito). |
| `from`              | Indirizzo mittente                                                          |

**Nota porta 465 (SMTPS):** la connessione viene wrappata in SSL dal primo byte. Impostare `enable_starttls_auto` a `false` non è sufficiente: occorre usare la porta `465` affinché `SmtpConfig` abiliti automaticamente `tls: true`. Le due modalità (SMTPS e STARTTLS) sono mutuamente esclusive — mescolarle causa un `Net::ReadTimeout`.

### Usare SmtpDeliverable nei mailer

Includere il concern `SmtpDeliverable` in qualsiasi `ActionMailer::Base` per leggere le impostazioni SMTP da `ThecoreSettings` al momento dell'invio (nessun riavvio necessario quando le impostazioni cambiano):

```ruby
class MyMailer < ApplicationMailer
  include SmtpDeliverable

  def my_email
    mail(
      from: smtp_setting(:from),
      to: "recipient@example.com",
      subject: "Hello"
    )
  end
end
```

Il concern registra automaticamente un `after_action :configure_smtp_delivery` che sovrascrive il delivery method con le impostazioni lette da `ThecoreSettings`. Se `smtp.address` è vuoto, il mailer usa il delivery method configurato nell'ambiente Rails (es. `:test` o `:letter_opener` in sviluppo).

Il metodo helper `smtp_setting(key)` è disponibile in tutta la classe mailer.

### Usare SmtpConfig direttamente

`ThecoreBackendCommons::SmtpConfig` è un modulo Ruby puro utilizzabile anche al di fuori dei mailer (es. script, job, rake task):

```ruby
opts = ThecoreBackendCommons::SmtpConfig.delivery_options
# => { address: "smtp.example.com", port: 465, tls: true, ... }

ThecoreBackendCommons::SmtpConfig.setting(:from)
# => "noreply@example.com"
```

### Testare la configurazione SMTP

Dall'applicazione Rails che include questo gem, eseguire:

```bash
bundle exec rails runner script/test_smtp.rb destinatario@example.com
```

Se non si passa un indirizzo, l'email viene inviata all'indirizzo configurato in `ThecoreSettings mytask.default_email`.

Lo script stampa i parametri SMTP effettivamente usati (inclusi `tls` e `enable_starttls_auto`) prima di tentare la consegna, e restituisce exit code `1` in caso di errore con il messaggio dell'eccezione.

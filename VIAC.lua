WebBanking{version     = 1.00,
           url         = "https://app.viac.ch/",
           services    = {"VIAC Säule 3a"},
           description = "VIAC Säule 3a Konto (CH)"}

-- Globale Variablen für die Session-Verwaltung
local connection = nil
local sessionCookies = nil
local csrfToken = nil

-- Debug-Einstellungen
local DEBUG_MODE = true

-- Hilfsfunktion zum Loggen
local function log(message)
  if DEBUG_MODE then
    print(extensionName .. ": " .. message)
  end
end

-- Funktion zum Extrahieren von CSRF-Token aus HTML
local function extractCSRFToken(html)
  -- Suche nach dem CSRF-Token in den JavaScript-Dateien oder als Meta-Tag
  local csrfTokenPattern = 'nonce="([^"]+)"'
  local token = string.match(html, csrfTokenPattern)
  
  if token then
    log("CSRF-Token gefunden: " .. token)
    return token
  else
    log("CSRF-Token konnte nicht gefunden werden")
    return nil
  end
end

-- API-URLs
local LOGIN_URL = "https://app.viac.ch/external-login/public/authentication/password/check/"
local PORTFOLIO_URL = "https://app.viac.ch/rest/web/wealth/portfolio-inventory"
local DASHBOARD_URL = "https://app.viac.ch/"
local P3A_PORTFOLIO_URL_BASE = "https://app.viac.ch/rest/web/p3a/portfolio/" -- Basis-URL für p3a Portfolio Operationen
local ASSETS_OVERVIEW_SUFFIX = "/assetsOverview" -- Suffix für die detaillierte Vermögensübersicht

function SupportsBank(protocol, bankCode)
  log("SupportsBank aufgerufen mit protocol=" .. tostring(protocol) .. ", bankCode=" .. tostring(bankCode))
  return protocol == ProtocolWebBanking and bankCode == "VIAC Säule 3a"
end

function InitializeSession(protocol, bankCode, username, reserved, password)
  log("InitializeSession aufgerufen für VIAC Säule 3a")
  
  -- Telefonnummer bereinigen (falls mit + oder anderen Zeichen)
  local phoneNumber = username
  if string.match(username, "%+") then
    log("Telefonnummer enthält +, wird unverändert verwendet: " .. phoneNumber)
  end
  
  -- Neue Verbindung erstellen
  connection = Connection()
  connection.useragent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36"
  connection.language = "de-DE"
  
  -- 1. Hauptseite laden, um CSRF-Token und Cookies zu erhalten
  log("Lade Hauptseite: " .. DASHBOARD_URL)
  local htmlContent, charset, mimeType = connection:request("GET", DASHBOARD_URL)
  if not htmlContent then
    log("Fehler beim Laden der Hauptseite.")
    return "Fehler beim Laden der Hauptseite."
  end
  
  -- CSRF-Token aus der Seite extrahieren
  csrfToken = extractCSRFToken(htmlContent)
  if not csrfToken then
    log("Kein CSRF-Token gefunden, versuche es mit statischem Token.")
    csrfToken = "VSSLeRI55k668AQ0OsCE6w" -- Statischer Fallback-Token aus dem vorherigen Code
  end
  
  -- Cookies speichern
  sessionCookies = connection:getCookies()
  log("Cookies nach Laden der Hauptseite: " .. (sessionCookies or "keine"))
  
  -- 2. Login über API
  log("Führe Login durch via: " .. LOGIN_URL)
  
  -- Headers für die API-Anfrage
  local headers = {
    ["Content-Type"] = "application/json",
    ["X-CSRFT759"] = csrfToken,
    ["X-Same-Domain"] = "1",
    ["Cache-control"] = "no-cache, no-store",
    ["Pragma"] = "no-cache",
    ["Expires"] = "0",
    ["Accept"] = "application/json",
    ["Origin"] = "https://app.viac.ch",
    ["Referer"] = "https://app.viac.ch/"
  }
  
  -- Login-Daten als JSON
  local loginData = {
    username = phoneNumber,
    password = password
  }
  
  -- Debug-Ausgabe der Header und Payload
  log("Login Headers:")
  for k, v in pairs(headers) do log("  " .. k .. ": " .. v) end
  log("Login Payload: username=" .. phoneNumber .. ", password=****")
  
  -- Login-Anfrage senden
  local loginJsonPayload = JSON():set(loginData):json()
  local content, charset, mimeType, filename, responseHeaders = connection:request(
    "POST", LOGIN_URL, loginJsonPayload, "application/json", headers
  )
  
  -- Prüfen, ob Antwort empfangen wurde
  if not content then
    log("Keine Antwort vom Server erhalten")
    return "Keine Antwort vom Server erhalten."
  end
  
  -- Cookies nach dem Login speichern
  sessionCookies = connection:getCookies()
  log("Cookies nach Login: " .. (sessionCookies or "keine"))
  
  -- Antwort vom Server analysieren
  log("Login-Antwort erhalten:")
  log(content)
  
  -- Erfolg prüfen
  local jsonResponse = JSON(content):dictionary()
  if jsonResponse and jsonResponse.data and jsonResponse.data.type == "authentication.session" then
    log("Login erfolgreich!")
    return nil -- Erfolg
  else
    log("Login fehlgeschlagen: Unerwartete Antwort vom Server")
    return LoginFailed
  end
end

function ListAccounts(knownAccounts)
  log("ListAccounts aufgerufen")
  
  if not connection then
    log("Keine aktive Verbindung gefunden")
    return "Keine aktive Verbindung gefunden (ListAccounts)."
  end
  
  if not sessionCookies then
    log("Keine Session-Cookies gefunden")
    return "Keine Session-Cookies gefunden."
  end
  
  connection:setCookie(sessionCookies)
  
  local headers = {
    ["Accept"] = "application/json",
    ["X-CSRFT759"] = csrfToken,
    ["X-Same-Domain"] = "1",
    ["Origin"] = "https://app.viac.ch",
    ["Referer"] = "https://app.viac.ch/",
    ["Cookie"] = sessionCookies
  }
  
  -- Versuchen, den Benutzernamen zu holen (Fallback)
  local userName = "VIAC-Kunde"
  log("Benutzername (Fallback): " .. userName)
  
  -- Portfolio-Inventardaten holen
  log("Rufe Portfolio-Inventar ab: " .. PORTFOLIO_URL)
  local content, _, _, _, _ = connection:request("GET", PORTFOLIO_URL, nil, nil, headers)
  
  if not content then
    log("Keine Antwort vom Server erhalten (Portfolio-Inventar)")
    return "Keine Antwort vom Server erhalten (Portfolio-Inventar)."
  end
  
  log("Portfolio-Inventar Antwort erhalten:")
  log(content)
  
  local jsonResponse = JSON(content):dictionary()
  if not jsonResponse then
    log("Fehler beim Parsen der JSON-Antwort für Portfolio-Inventar")
    return "Fehler beim Parsen der JSON-Antwort für Portfolio-Inventar."
  end
  
  local accounts = {}
  
  if jsonResponse.p3a and #jsonResponse.p3a > 0 then
    log("Anzahl gefundener VIAC-Portfolios im Inventar: " .. #jsonResponse.p3a)
    
    for _, portfolio in ipairs(jsonResponse.p3a) do
      local portfolioNumber = portfolio.number
      local portfolioName = portfolio.name
      
      -- Für jedes VIAC-Portfolio ein eigenes MoneyMoney-Konto erstellen
      local account = {
        name = "VIAC " .. portfolioName,
        accountNumber = portfolioNumber,
        owner = userName,
        bankCode = "VIAC",
        currency = "CHF",
        type = AccountTypePortfolio,
        portfolio = true
      }
      
      log("Erstelle MoneyMoney Konto für VIAC Portfolio: " .. portfolioName .. " (Nr: " .. portfolioNumber .. ")")
      table.insert(accounts, account)
    end
  else
    log("Keine p3a Portfolios im Inventar gefunden.")
    -- Fallback-Konto erstellen, falls keine Portfolios gefunden wurden
    local account = {
      name = "VIAC Säule 3a",
      accountNumber = "VIAC-MAIN",
      owner = userName,
      bankCode = "VIAC",
      currency = "CHF",
      type = AccountTypePortfolio,
      portfolio = true
    }
    log("Erstelle Fallback-Konto: " .. account.name)
    table.insert(accounts, account)
  end
  
  return accounts
end

function RefreshAccount(account, since)
  log("RefreshAccount aufgerufen für MoneyMoney-Konto: " .. account.name .. " (ID: " .. account.accountNumber .. ")")
  
  if not connection then
    log("Keine aktive Verbindung gefunden")
    return "Keine aktive Verbindung gefunden (RefreshAccount)."
  end
  
  if not sessionCookies then
    log("Keine Session-Cookies gefunden")
    return "Keine Session-Cookies gefunden."
  end
  
  connection:setCookie(sessionCookies)
  
  local headers = {
    ["Accept"] = "application/json",
    ["X-CSRFT759"] = csrfToken,
    ["X-Same-Domain"] = "1",
    ["Origin"] = "https://app.viac.ch",
    ["Referer"] = "https://app.viac.ch/",
    ["Cookie"] = sessionCookies
  }
  
  -- Portfolio-Nummer ist direkt die accountNumber (oder das Fallback-Konto)
  local portfolioNumber = account.accountNumber
  if portfolioNumber == "VIAC-MAIN" then
    log("Fallback-Konto - keine Daten abfragbar")
    return {balance = 0, securities = {}}
  end
  
  -- assetsOverview für dieses Portfolio abrufen
  local assetsOverviewURL = P3A_PORTFOLIO_URL_BASE .. portfolioNumber .. ASSETS_OVERVIEW_SUFFIX
  log("Rufe assetsOverview ab von: " .. assetsOverviewURL)
  
  local content, _, _, _, responseHeaders = connection:request("GET", assetsOverviewURL, nil, nil, headers)
  
  -- Initialwerte
  local cashAmount = 0
  local securities = {}
  
  if content then
    log("assetsOverview Antwort erhalten für Portfolio " .. portfolioNumber .. ":")
    log(content)
    
    local jsonAssetsOverview = JSON(content):dictionary()
    if jsonAssetsOverview then
      -- Cash-Anteil des Portfolios als Kontostand verwenden
      if type(jsonAssetsOverview.cashAmount) == "number" then
        cashAmount = jsonAssetsOverview.cashAmount
        log("Cash-Anteil (balance) für Portfolio " .. account.name .. ": " .. cashAmount .. " CHF")
        
        -- Cash-Anteil auch als eigene Position im Portfolio hinzufügen
        local cashSecurity = {
          name = "Liquidität",
          isin = "VIAC-" .. portfolioNumber .. "-CASH",
          quantity = 1.0,
          price = cashAmount,
          amount = cashAmount,
          currencyOfPrice = "CHF"
        }
        table.insert(securities, cashSecurity)
        log("Cash-Anteil auch als Wertpapier hinzugefügt: " .. cashSecurity.name .. " (" .. cashAmount .. " CHF)")
      else
        log("Kein numerischer cashAmount für Portfolio " .. account.name .. " gefunden.")
      end
      
      -- Wertpapiere des Portfolios verarbeiten (keine Cash-Anteile als Wertpapiere)
      if jsonAssetsOverview.assetsByClasses and type(jsonAssetsOverview.assetsByClasses) == "table" then
        for assetClassName, assetsInClass in pairs(jsonAssetsOverview.assetsByClasses) do
          log("Verarbeite Anlageklasse: " .. assetClassName)
          if type(assetsInClass) == "table" then
            for _, assetItem in ipairs(assetsInClass) do
              local assetName = assetItem.name
              local assetIsin = assetItem.isin
              local assetRatioInChf = assetItem.ratioInChf
              local assetAmount = assetItem.amount -- Anzahl der Anteile
              local assetPrice = assetItem.assetPrice -- Preis pro Anteil
              local currencyCode = assetItem.currencyCode or "CHF"
              
              if assetName and assetIsin and type(assetRatioInChf) == "number" then
                log("Wertpapier gefunden: " .. assetName .. " (ISIN: " .. assetIsin .. "), Wert: " .. assetRatioInChf .. " CHF")
                
                -- Details für das Wertpapier ausgeben
                if type(assetAmount) == "number" and type(assetPrice) == "number" then
                  log("  Anzahl: " .. assetAmount .. ", Preis pro Anteil: " .. assetPrice .. " " .. currencyCode)
                end
                
                -- Kaufpreis (Einstandskurs) extrahieren für Gewinn/Verlust-Berechnung
                local acquisitionPrice = nil
                local rateOfReturn = nil
                if type(assetItem.acquisitionPrice) == "number" then
                  acquisitionPrice = assetItem.acquisitionPrice
                  log("  Kaufpreis pro Anteil: " .. acquisitionPrice .. " " .. currencyCode)
                end
                
                if type(assetItem.rateOfReturn) == "number" then
                  rateOfReturn = assetItem.rateOfReturn * 100 -- In Prozent umwandeln für bessere Lesbarkeit im Log
                  log("  Rendite: " .. string.format("%.2f", rateOfReturn) .. "%")
                end
                
                -- Wertpapier zum Portfolio hinzufügen
                -- Verwende assetAmount und assetPrice, wenn verfügbar, sonst verwende 1.0 als Menge und ratioInChf als Preis
                local quantity = type(assetAmount) == "number" and assetAmount or 1.0
                local price = type(assetPrice) == "number" and assetPrice or assetRatioInChf
                
                local security = {
                  name = assetName,
                  isin = assetIsin,
                  quantity = quantity,
                  price = price,
                  amount = assetRatioInChf, -- Gesamtwert in CHF
                  currencyOfPrice = currencyCode
                }
                
                -- Kaufpreis hinzufügen, wenn verfügbar
                if acquisitionPrice then
                  security.purchasePrice = acquisitionPrice
                end
                
                table.insert(securities, security)
                log("Wertpapier " .. assetName .. " hinzugefügt.")
              else
                log("Ungültige Daten für Wertpapier-Item unter " .. assetClassName)
              end
            end
          else
            log("assetsInClass für " .. assetClassName .. " ist keine Tabelle.")
          end
        end
      else
        log("Kein assetsByClasses Objekt oder es ist keine Tabelle für Portfolio " .. portfolioNumber)
      end
    else
      log("Fehler beim Parsen der JSON-Antwort für assetsOverview " .. portfolioNumber)
    end
  else
    log("Keine Antwort vom Server für assetsOverview " .. portfolioNumber .. ". Status: " .. (responseHeaders and responseHeaders[":status"] or "unbekannt"))
  end
  
  log("Kontostand (Cash): " .. cashAmount .. " CHF, Anzahl Wertpapiere: " .. #securities)
  
  -- Rückgabe: Cash als balance, Wertpapiere als securities
  return {balance = cashAmount, securities = securities}
end

function EndSession()
  log("EndSession aufgerufen")
  
  if connection then
    -- Versuche, den Logout durchzuführen - aber ignoriere Fehler
    if sessionCookies then
      -- Statt direktem Aufruf der Logout-URL, versuchen wir die Sitzung anders zu beenden
      -- Option 1: Mit API-Endpunkt (falls verfügbar)
      local logoutUrls = {
        "https://app.viac.ch/auth/logout",
        "https://app.viac.ch/api/auth/logout",
        "https://app.viac.ch/external-login/public/logout"
      }
      
      local headers = {
        ["X-CSRFT759"] = csrfToken,
        ["X-Same-Domain"] = "1",
        ["Cookie"] = sessionCookies,
        ["Accept"] = "application/json"
      }
      
      for _, logoutUrl in ipairs(logoutUrls) do
        log("Versuche Logout mit URL: " .. logoutUrl)
        local success, err = pcall(function()
          connection:request("GET", logoutUrl, nil, nil, headers)
        end)
        
        if success then
          log("Logout-Versuch mit URL " .. logoutUrl .. " durchgeführt")
          break
        else
          log("Logout mit URL " .. logoutUrl .. " fehlgeschlagen, versuche alternative Methode")
        end
      end
    end
    
    -- Unabhängig vom Erfolg des expliziten Logouts, schließen wir die Verbindung
    log("Schließe Verbindung")
    connection:close()
    connection = nil
    sessionCookies = nil
    csrfToken = nil
  end
  
  return nil -- Erfolg, auch wenn Logout nicht funktioniert hat
end

log("VIAC Extension geladen.") 

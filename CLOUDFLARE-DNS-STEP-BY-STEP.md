# Cloudflare DNS Setup - Step by Step Guide
**For: kludgebot.bot**

---

## 📋 Information You Need

**Your OVH Server IP Addresses:**
- **IPv4:** `40.160.237.83` ← Use this one
- **IPv6:** `2604:2dc0:306::4:0:4a` ← Optional

**Domain:** `kludgebot.bot` (already transferred to Cloudflare ✓)

---

## 🎯 Step 1: Log into Cloudflare

1. Go to: https://dash.cloudflare.com/
2. Log in with your Cloudflare account
3. You should see your domains listed

---

## 🎯 Step 2: Select Your Domain

1. Click on **`kludgebot.bot`** in the domain list
2. This takes you to the domain dashboard

---

## 🎯 Step 3: Go to DNS Settings

1. On the left sidebar, click **"DNS"**
2. You'll see a section called **"DNS Records"**
3. This is where we'll add records

---

## 🎯 Step 4: Add A Record for Root Domain (@)

**What this does:** Makes `kludgebot.bot` point to your server

1. Click the **"Add record"** button
2. Fill in these exact values:

```
┌─────────────────────────────────────────────┐
│ Type: A                                     │
│ Name: @                                     │
│ IPv4 address: 40.160.237.83                │
│ Proxy status: DNS only (gray cloud) ⚠️     │
│ TTL: Auto                                   │
└─────────────────────────────────────────────┘
```

**CRITICAL:** Make sure the cloud icon is **GRAY** (not orange)!
- Gray cloud = DNS only (what we want now)
- Orange cloud = Proxied (turn on AFTER SSL is working)

3. Click **"Save"**

---

## 🎯 Step 5: Add A Record for WWW

**What this does:** Makes `www.kludgebot.bot` also point to your server

1. Click **"Add record"** again
2. Fill in these exact values:

```
┌─────────────────────────────────────────────┐
│ Type: A                                     │
│ Name: www                                   │
│ IPv4 address: 40.160.237.83                │
│ Proxy status: DNS only (gray cloud) ⚠️     │
│ TTL: Auto                                   │
└─────────────────────────────────────────────┘
```

**CRITICAL:** Again, make sure the cloud is **GRAY**!

3. Click **"Save"**

---

## 🎯 Step 6: Verify Your DNS Records

After adding both records, you should see:

```
TYPE    NAME    CONTENT            PROXY STATUS
────────────────────────────────────────────────
A       @       40.160.237.83      DNS only 🩶
A       www     40.160.237.83      DNS only 🩶
```

If you see orange clouds 🟠, click them to turn them gray!

---

## 🎯 Step 7: Check DNS Propagation (5-10 minutes)

**On your server, run these commands to test:**

```bash
# Test root domain
dig +short kludgebot.bot

# Test www subdomain  
dig +short www.kludgebot.bot

# Both should return: 40.160.237.83
```

**OR use online tool:**
- https://dnschecker.org/
- Enter: `kludgebot.bot`
- Should show your IP worldwide

---

## ✅ You're Done with Basic DNS!

Once the `dig` commands return your IP address, DNS is working!

**Next steps (we'll do together):**
1. ✅ Basic DNS (you just did this!)
2. 🔜 Set up email forwarding (next)
3. 🔜 Install SSL certificate (after DNS propagates)

---

## 🚨 Common Mistakes to Avoid

### ❌ Wrong: Orange Cloud Initially
```
A  @  40.160.237.83  🟠 Proxied
```
**Problem:** SSL certificate installation will fail!

### ✅ Correct: Gray Cloud Initially  
```
A  @  40.160.237.83  🩶 DNS only
```
**Why:** Let's Encrypt needs to reach YOUR server directly

**You can turn on proxy (orange cloud) AFTER SSL is installed!**

---

## 📝 Screenshot Checklist

When you're in Cloudflare, it should look like this:

```
┌─────────────────────────────────────────────────────────────┐
│  DNS Records for kludgebot.bot                              │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  [Add record]                                                │
│                                                              │
│  Type  Name   Content          Proxy status    Actions     │
│  ────  ────   ─────────────    ────────────    ───────     │
│  A     @      40.160.237.83    🩶 DNS only     [Edit]      │
│  A     www    40.160.237.83    🩶 DNS only     [Edit]      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 🆘 Need Help?

**DNS not propagating?**
- Wait 5-10 minutes
- Check https://dnschecker.org/
- Some locations update faster than others

**Can't find the "Add record" button?**
- Make sure you're in the "DNS" section (left sidebar)
- Scroll down if needed

**Cloud icon keeps turning orange?**
- Click the orange cloud to toggle it to gray
- Cloudflare wants to proxy by default (we'll enable later)

**Wrong IP address entered?**
- Click "Edit" next to the record
- Fix the IP address
- Save again

---

## 🎉 What Happens Next

Once DNS propagates:
1. `kludgebot.bot` → Points to your OVH server ✅
2. `www.kludgebot.bot` → Points to your OVH server ✅
3. We can install SSL certificate 🔒
4. Website will work with HTTPS 🎉

---

**When you're done, let me know and I'll verify DNS is working!** 🚀

**Pro tip:** Keep this browser tab open - we'll come back to add email records next!

import webpush from 'web-push';
import Config from '../models/Config.ts';
import User from '../models/User.ts';

let isInitialized = false;
let publicKey = '';

export const initWebPush = async () => {
  try {
    let vapidConfig = await Config.findOne({ key: 'vapid_keys' });
    
    if (!vapidConfig) {
      const keys = webpush.generateVAPIDKeys();
      vapidConfig = new Config({ key: 'vapid_keys', value: keys });
      await vapidConfig.save();
    }
    
    const { publicKey: pKey, privateKey } = vapidConfig.value;
    publicKey = pKey;
    
    // Set VAPID details
    webpush.setVapidDetails(
      'mailto:admin@bloodlink.example',
      publicKey,
      privateKey
    );
    
    isInitialized = true;
    console.log('Web Push VAPID keys loaded successfully.');
    return publicKey;
  } catch (error) {
    console.error('Failed to initialize web push:', error);
    return null;
  }
};

export const getPublicKey = () => publicKey;

export const sendWebPush = async (userId: string, title: string, message: string, link: string) => {
  if (!isInitialized) return;
  
  try {
    const user = await User.findById(userId);
    if (!user || !user.pushSubscriptions || user.pushSubscriptions.length === 0) return;
    
    const payload = JSON.stringify({
      title,
      message,
      link
    });
    
    const subscriptions = user.pushSubscriptions;
    let staleCount = 0;
    
    for (let i = 0; i < subscriptions.length; i++) {
        const sub = subscriptions[i];
        try {
            await webpush.sendNotification(sub, payload);
        } catch (error: any) {
            if (error && (error.statusCode === 410 || error.statusCode === 404)) {
                // Subscription has expired or is no longer valid
                subscriptions[i] = null;
                staleCount++;
            } else {
                console.error('Error sending push feature:', error);
            }
        }
    }
    
    if (staleCount > 0) {
        user.pushSubscriptions = subscriptions.filter(s => s !== null);
        await user.save();
    }
    
  } catch (err) {
    console.error('Error handling push workflow:', err);
  }
};

// Also we can define a broadcast helper (excluding the creator)
export const broadcastWebPush = async (excludeUserId: string | null, title: string, message: string, link: string) => {
  if (!isInitialized) return;
  
  try {
    const query = excludeUserId ? { _id: { $ne: excludeUserId } } : {};
    const users = await User.find(query);
    
    const payload = JSON.stringify({ title, message, link });
    let totalSent = 0;
    
    for (const user of users) {
        if (!user.pushSubscriptions || user.pushSubscriptions.length === 0) continue;
        
        let shouldSave = false;
        const subs = user.pushSubscriptions;
        
        for (let i = 0; i < subs.length; i++) {
            if (!subs[i]) continue;
            try {
                await webpush.sendNotification(subs[i], payload);
                totalSent++;
            } catch (err: any) {
               if (err && (err.statusCode === 410 || err.statusCode === 404)) {
                   subs[i] = null;
                   shouldSave = true;
               }
            }
        }
        
        if (shouldSave) {
            user.pushSubscriptions = subs.filter(s => s !== null);
            await user.save();
        }
    }
    console.log(`Broadcasted web push to ${totalSent} devices.`);
  } catch (err) {
    console.error('Error broadcasting web push:', err);
  }
};

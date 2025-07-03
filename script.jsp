// Initialize Supabase client
const SUPABASE_URL = 'https://tylfegbogggvcqixklml.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR5bGZlZ2JvZ2dndmNxaXhrbG1sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE1NjU4MTAsImV4cCI6MjA2NzE0MTgxMH0.YtvFrio3LgJ26sy16lVA3w05h80RPJcLmwcgrJMsf08';

const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// DOM elements
const form = document.getElementById('meal-form');
const photoInput = document.getElementById('photo');
const canvas = document.getElementById('canvas');
const statusDiv = document.getElementById('status');
const submitBtn = document.getElementById('submit-btn');
const recentList = document.getElementById('recent-list');

// Set current date and time as defaults
document.getElementById('meal-date').valueAsDate = new Date();
document.getElementById('meal-time').value = new Date().toLocaleTimeString('en-US', {
    hour12: false,
    hour: '2-digit',
    minute: '2-digit'
});

// Compress image function
function compressImage(file, maxWidth = 800, quality = 0.8) {
    return new Promise((resolve) => {
        const ctx = canvas.getContext('2d');
        const img = new Image();
        
        img.onload = () => {
            // Calculate new dimensions
            const ratio = Math.min(maxWidth / img.width, maxWidth / img.height);
            const newWidth = img.width * ratio;
            const newHeight = img.height * ratio;
            
            // Set canvas size
            canvas.width = newWidth;
            canvas.height = newHeight;
            
            // Draw and compress
            ctx.drawImage(img, 0, 0, newWidth, newHeight);
            canvas.toBlob(resolve, 'image/jpeg', quality);
        };
        
        img.src = URL.createObjectURL(file);
    });
}

// Upload photo to Supabase Storage
async function uploadPhoto(file) {
    try {
        const compressedFile = await compressImage(file);
        const fileName = `meal_${Date.now()}_${Math.random().toString(36).substr(2, 9)}.jpg`;
        
        const { data, error } = await supabase.storage
            .from('meal-photos')
            .upload(fileName, compressedFile);
        
        if (error) throw error;
        
        // Get public URL
        const { data: urlData } = supabase.storage
            .from('meal-photos')
            .getPublicUrl(fileName);
        
        return urlData.publicUrl;
    } catch (error) {
        console.error('Photo upload error:', error);
        throw error;
    }
}

// Show status message
function showStatus(message, isError = false) {
    statusDiv.textContent = message;
    statusDiv.className = `status ${isError ? 'error' : 'success'}`;
    statusDiv.style.display = 'block';
    
    setTimeout(() => {
        statusDiv.style.display = 'none';
    }, 5000);
}

// Load recent meals
async function loadRecentMeals() {
    try {
        const { data, error } = await supabase
            .from('meal_entries')
            .select('*')
            .order('created_at', { ascending: false })
            .limit(5);
        
        if (error) throw error;
        
        recentList.innerHTML = '';
        
        data.forEach(meal => {
            const mealDiv = document.createElement('div');
            mealDiv.className = 'meal-item';
            
            const date = new Date(meal.created_at).toLocaleDateString();
            const time = meal.meal_time;
            const status = meal.processed ? 
                (meal.calories ? `${meal.calories} cal` : 'Processed') : 
                'Pending analysis';
            
            mealDiv.innerHTML = `
                <div class="meal-header">${meal.meal_type.charAt(0).toUpperCase() + meal.meal_type.slice(1)} - ${status}</div>
                <div class="meal-description">${meal.description}</div>
                <div class="meal-meta">${date} at ${time}</div>
            `;
            
            recentList.appendChild(mealDiv);
        });
    } catch (error) {
        console.error('Error loading recent meals:', error);
    }
}

// Form submission
form.addEventListener('submit', async (e) => {
    e.preventDefault();
    
    submitBtn.disabled = true;
    submitBtn.textContent = 'Logging...';
    
    try {
        const formData = new FormData(form);
        let photoUrl = null;
        
        // Upload photo if provided
        if (photoInput.files[0]) {
            showStatus('Uploading photo...');
            photoUrl = await uploadPhoto(photoInput.files[0]);
        }
        
        // Insert meal entry
        const { data, error } = await supabase
            .from('meal_entries')
            .insert([{
                meal_type: document.getElementById('meal-type').value,
                meal_date: document.getElementById('meal-date').value,
                meal_time: document.getElementById('meal-time').value,
                description: document.getElementById('description').value,
                photo_url: photoUrl
            }]);
        
        if (error) throw error;
        
        showStatus('Meal logged successfully! 🎉');
        form.reset();
        
        // Reset date and time to current
        document.getElementById('meal-date').valueAsDate = new Date();
        document.getElementById('meal-time').value = new Date().toLocaleTimeString('en-US', {
            hour12: false,
            hour: '2-digit',
            minute: '2-digit'
        });
        
        // Reload recent meals
        await loadRecentMeals();
        
    } catch (error) {
        console.error('Error logging meal:', error);
        showStatus('Error logging meal. Please try again.', true);
    } finally {
        submitBtn.disabled = false;
        submitBtn.textContent = 'Log Meal';
    }
});

// Load recent meals on page load
document.addEventListener('DOMContentLoaded', loadRecentMeals);
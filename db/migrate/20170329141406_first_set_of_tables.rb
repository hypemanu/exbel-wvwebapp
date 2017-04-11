class FirstSetOfTables < ActiveRecord::Migration[5.0]
  def change
    enable_extension 'uuid-ossp'
    
    create_table :bookfrags, force: :cascade do |t|
      t.string   :fragment
      t.integer  :book_id
      t.datetime :created_at
      t.datetime :updated_at
    end

    create_table :chapters, force: :cascade do |t|
      t.string   :name
      t.integer  :book_id
      t.integer  :chapter
      t.integer  :chapter_index
      t.datetime :created_at
      t.datetime :updated_at
    end

    create_table :exbel_stats, force: :cascade do |t|
      t.string   :msg_in_24hr
      t.string   :msg_in_7d
      t.string   :msg_in_30d
      t.string   :total_users
      t.string   :total_groups
      t.string   :top_chapter
      t.string   :top_group
      t.datetime :created_at,   null: false
      t.datetime :updated_at,   null: false
    end

    create_table :group_invites, id: :uuid, default: "uuid_generate_v4()", force: :cascade do |t|
      t.integer  :group_id
      t.integer  :sender_id
      t.string   :name
      t.string   :email      
      t.integer  :status,     default: 1
      t.datetime :created_at,             null: false
      t.datetime :updated_at,             null: false
    end

    add_index "group_invites", ["group_id"], name: "index_group_invites_on_group_id", using: :btree

    create_table :groups, force: :cascade do |t|
      t.string   :name
      t.string   :key
      t.integer  :owner_id
      t.datetime :created_at
      t.datetime :updated_at
      t.date     :last_read_on
    end

    create_table :readings, force: :cascade do |t|
      t.integer  :user_id
      t.integer  :chapter_id
      t.datetime :created_at
      t.datetime :updated_at
      t.date     :date_read
    end

    add_index "readings", ["created_at"], name: "index_readings_on_created_at", using: :btree
    add_index "readings", ["date_read"], name: "index_readings_on_date_read", using: :btree
    add_index "readings", ["user_id"], name: "index_readings_on_user_id", using: :btree

    create_table :sessions, force: :cascade do |t|
      t.text     :session_id, null: false
      t.text     :data
      t.datetime :created_at
      t.datetime :updated_at
    end

    add_index "sessions", ["session_id"], name: "index_sessions_on_session_id", using: :btree
    add_index "sessions", ["updated_at"], name: "index_sessions_on_updated_at", using: :btree

    create_table :taggings, force: :cascade do |t|
      t.integer  :tag_id
      t.integer  :taggable_id
      t.string   :taggable_type
      t.integer  :tagger_id
      t.string   :tagger_type
      t.string   :context
      t.datetime :created_at
    end

    add_index "taggings", ["tag_id", "taggable_id", "taggable_type", "context", "tagger_id", "tagger_type"], name: "taggings_idx", unique: true, using: :btree

    create_table :tags, force: :cascade do |t|
      t.string  :name
      t.integer :taggings_count, default: 0
    end

    add_index "tags", ["name"], name: "index_tags_on_name", unique: true, using: :btree

    create_table :users, force: :cascade do |t|
      ## Database authenticatable
      t.string   :email
      t.string   :encrypted_password,         default: "",                           null: false
      ## Recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at
      ## Rememberable
      t.datetime :remember_created_at
      ## Trackable
      t.integer  :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.inet     :current_sign_in_ip
      t.inet     :last_sign_in_ip
      ## Confirmable
      t.string   :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string   :unconfirmed_email

      t.string   :name
      t.string   :phone_number
      t.string   :timezone,                   default: "Eastern Time (US & Canada)"
      t.string   :image_url
      t.string   :uid
      t.string   :provider
      t.integer  :group_id
      t.date     :joined_group_on
      
      t.string   :avatar_file_name
      t.string   :avatar_content_type
      t.integer  :avatar_file_size
      t.datetime :avatar_updated_at
      t.boolean  :banned,                     default: false
      t.boolean  :muted,                      default: false
      
      t.boolean  :public_readings,            default: true
      t.boolean  :is_visible_on_leaderboards, default: true
      t.boolean  :notify_on_wall_post,        default: true
      t.boolean  :send_monthly_report,        default: true
      t.boolean  :receive_weekly_emails,      default: true,                         null: false
    end

    add_index :users, :email,                unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :group_id
    add_index :users, :phone_number
    add_index :users, [:provider, :uid]

    add_foreign_key :group_invites, :groups    
  end
end

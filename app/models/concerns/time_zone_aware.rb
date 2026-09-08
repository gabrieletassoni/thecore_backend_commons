module TimeZoneAware
  extend ActiveSupport::Concern

  class_methods do
    # Declares that +field+ (an existing UTC datetime column) is time-zone aware:
    # adds a nullable, client-writable +<field>_time_zone+ column reader/validation,
    # and exposes +<field>_server_tz+/+<field>_record_tz+ computed JSON attributes.
    # The +<field>_time_zone+ column itself must already exist (added via migration).
    def time_zone_aware(*fields)
      fields.each do |field|
        time_zone_attr = :"#{field}_time_zone"

        validate do
          TimeZoneAware.validate_zone(self, time_zone_attr)
        end

        define_method(:"#{field}_server_tz") do
          TimeZoneAware.localize(read_attribute(field), TimeZoneAware.server_time_zone)
        end

        define_method(:"#{field}_record_tz") do
          zone = read_attribute(time_zone_attr).presence || TimeZoneAware.server_time_zone
          TimeZoneAware.localize(read_attribute(field), zone)
        end

        cattr_accessor :json_attrs unless respond_to?(:json_attrs)
        self.json_attrs = ::ModelDrivenApi.smart_merge(json_attrs || {}, {
          methods: [:"#{field}_server_tz", :"#{field}_record_tz"],
        })
      end
    end
  end

  # The deployment-wide IANA time zone identifier (ThecoreSettings ns: :main, key: :time_zone),
  # or nil when unset — callers treat a nil zone as "leave the UTC value unshifted".
  def self.server_time_zone
    ::Settings.ns(:main).time_zone.presence
  end

  # NULL-safe: localizes +value+ (a UTC datetime) to +zone_name+, or returns it
  # unshifted when there is no zone to localize to (nil value, blank/invalid zone name).
  def self.localize(value, zone_name)
    return nil if value.nil?

    zone = zone_name.present? ? ActiveSupport::TimeZone[zone_name] : nil
    zone ? value.in_time_zone(zone) : value
  end

  def self.valid_zone?(value)
    value.blank? || ActiveSupport::TimeZone[value].present?
  end

  def self.validate_zone(record, attr)
    record.errors.add(attr, :invalid) unless valid_zone?(record.read_attribute(attr))
  end
end

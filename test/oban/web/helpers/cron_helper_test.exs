defmodule Oban.Web.Helpers.CronHelperTest do
  use ExUnit.Case, async: true

  describe "to_words/1" do
    import Oban.Web.Helpers.CronHelper, only: [to_words: 1]

    test "every X minutes" do
      assert to_words("* * * * *") == "Every minute"
      assert to_words("*/5 * * * *") == "Every 5 minutes"
    end

    # test "every X minutes" do
    #   assert to_words("* 0 * * *") == "Every minute, at 12:00 AM"
    # end
  end

  # it 'minute span' do
  #   expect(desc('0-10 11 * * *')).to eq('Every minute between 11:00 AM and 11:10 AM')
  # end

  # context 'every hour:' do
  #   it 'every hour 0 0' do
  #     expect(desc('0 0 * * * ?')).to eq('Every hour')
  #   end

  #   it 'every hour 0 0 0/1' do
  #     expect(desc('0 0 0/1 * * ?')).to eq('Every hour')
  #   end
  # end

  # context 'daily:' do
  #   it 'daily at /\d\d/:/\d\d/' do
  #     expect(desc('30 11 * * *')).to eq('At 11:30 AM')
  #   end

  #   it 'daily at /\d/:/\d/' do
  #     expect(desc('9 8 * * *')).to eq('At 8:09 AM')
  #   end

  #   it 'daily at /0[89]/:/0[89]/' do
  #     expect(desc('09 08 * * *')).to eq('At 8:09 AM')
  #   end

  #   it 'daily at /0[1-7]/ /0[1-7/' do
  #     expect(desc('02 01 * * *')).to eq('At 1:02 AM')
  #   end
  # end

  # context 'time of day certain days of week:' do
  #   it 'time of day on MON-FRI' do
  #     expect(desc('0 23 ? * MON-FRI')).to eq('At 11:00 PM, Monday through Friday')
  #   end

  #   it 'time of day on 1-5' do
  #     expect(desc('30 11 * * 1-5')).to eq('At 11:30 AM, Monday through Friday')
  #   end
  # end

  # it 'one month only' do
  #   expect(desc('* * * 3 *')).to eq('Every minute, only in March')
  # end

  # it 'two months only' do
  #   expect(desc('* * * 3,6 *')).to eq('Every minute, only in March and June')
  # end

  # it 'two times each afternoon' do
  #   expect(desc('30 14,16 * * *')).to eq('At 2:30 PM and 4:30 PM')
  # end

  # it 'three times daily' do
  #   expect(desc('30 6,14,16 * * *')).to eq('At 6:30 AM, 2:30 PM and 4:30 PM')
  # end

  # context 'once a week:' do
  #   it 'once a week 0' do
  #     expect(desc('46 9 * * 0')).to eq('At 9:46 AM, only on Sunday')
  #   end

  #   it 'once a week SUN' do
  #     expect(desc('46 9 * * SUN')).to eq('At 9:46 AM, only on Sunday')
  #   end

  #   it 'once a week 7' do
  #     expect(desc('46 9 * * 7')).to eq('At 9:46 AM, only on Sunday')
  #   end

  #   it 'once a week 1' do
  #     expect(desc('46 9 * * 1')).to eq('At 9:46 AM, only on Monday')
  #   end

  #   it 'once a week 6' do
  #     expect(desc('46 9 * * 6')).to eq('At 9:46 AM, only on Saturday')
  #   end
  # end

  # context 'once a week non zero based:' do
  #   it 'once a week 1' do
  #     expect(desc('46 9 * * 1', opts)).to eq('At 9:46 AM, only on Sunday')
  #   end

  #   it 'once a week SUN' do
  #     expect(desc('46 9 * * SUN', opts)).to eq('At 9:46 AM, only on Sunday')
  #   end

  #   it 'once a week 2' do
  #     expect(desc('46 9 * * 2', opts)).to eq('At 9:46 AM, only on Monday')
  #   end

  #   it 'once a week 7' do
  #     expect(desc('46 9 * * 7', opts)).to eq('At 9:46 AM, only on Saturday')
  #   end
  # end

  # context 'twice a week:' do
  #   it 'twice a week 1,2' do
  #     expect(desc('46 9 * * 1,2')).to eq('At 9:46 AM, only on Monday and Tuesday')
  #   end

  #   it 'twice a week MON,TUE' do
  #     expect(desc('46 9 * * MON,TUE')).to eq('At 9:46 AM, only on Monday and Tuesday')
  #   end

  #   it 'twice a week 0,6' do
  #     expect(desc('46 9 * * 0,6')).to eq('At 9:46 AM, only on Sunday and Saturday')
  #   end

  #   it 'twice a week 6,7' do
  #     expect(desc('46 9 * * 6,7')).to eq('At 9:46 AM, only on Saturday and Sunday')
  #   end
  # end

  # context 'twice a week non zero based:' do
  #   it 'twice a week 1,2' do
  #     expect(desc('46 9 * * 1,2', opts)).to eq('At 9:46 AM, only on Sunday and Monday')
  #   end

  #   it 'twice a week SUN,MON' do
  #     expect(desc('46 9 * * SUN,MON', opts)).to eq('At 9:46 AM, only on Sunday and Monday')
  #   end

  #   it 'twice a week 6,7' do
  #     expect(desc('46 9 * * 6,7', opts)).to eq('At 9:46 AM, only on Friday and Saturday')
  #   end
  # end

  # it 'day of month' do
  #   expect(desc('23 12 15 * *')).to eq('At 12:23 PM, on day 15 of the month')
  # end

  # it 'day of month with day of week' do
  #   expect(desc('23 12 15 * SUN')).to eq('At 12:23 PM, on day 15 of the month, only on Sunday')
  # end

  # it 'month name' do
  #   expect(desc('23 12 * JAN *')).to eq('At 12:23 PM, only in January')
  # end

  # it 'day of month with question mark' do
  #   expect(desc('23 12 ? JAN *')).to eq('At 12:23 PM, only in January')
  # end

  # it 'month name range 2' do
  #   expect(desc('23 12 * JAN-FEB *')).to eq('At 12:23 PM, January through February')
  # end

  # it 'month name range 3' do
  #   expect(desc('23 12 * JAN-MAR *')).to eq('At 12:23 PM, January through March')
  # end

  # it 'day of week name' do
  #   expect(desc('23 12 * * SUN')).to eq('At 12:23 PM, only on Sunday')
  # end

  # context 'day of week range:' do
  #   it 'day of week range MON-FRI' do
  #     expect(desc('*/5 15 * * MON-FRI')).to eq('Every 5 minutes, at 3:00 PM, Monday through Friday')
  #   end

  #   it 'day of week range 0-6' do
  #     expect(desc('*/5 15 * * 0-6')).to eq('Every 5 minutes, at 3:00 PM, Sunday through Saturday')
  #   end

  #   it 'day of week range 6-7' do
  #     expect(desc('*/5 15 * * 6-7')).to eq('Every 5 minutes, at 3:00 PM, Saturday through Sunday')
  #   end
  # end

  # context 'day of week once in month:' do
  #   it 'day of week once MON#3' do
  #     expect(desc('* * * * MON#3')).to eq('Every minute, on the third Monday of the month')
  #   end

  #   it 'day of week once 0#3' do
  #     expect(desc('* * * * 0#3')).to eq('Every minute, on the third Sunday of the month')
  #   end
  # end

  # context 'last day of week of the month:' do
  #   it 'last day of week 4L' do
  #     expect(desc('* * * * 4L')).to eq('Every minute, on the last Thursday of the month')
  #   end

  #   it 'last day of week 0L' do
  #     expect(desc('* * * * 0L')).to eq('Every minute, on the last Sunday of the month')
  #   end
  # end

  # context 'last day of the month:' do
  #   it 'on the last day of the month' do
  #     expect(desc('*/5 * L JAN *')).to eq('Every 5 minutes, on the last day of the month, only in January')
  #   end

  #   it 'between a day and last day of the month' do
  #     expect(desc('*/5 * 23-L JAN *')).to eq('Every 5 minutes, between day 23 and the last day of the month, only in January')
  #   end
  # end

  # it 'time of day with seconds' do
  #   expect(desc('30 02 14 * * *')).to eq('At 2:02:30 PM')
  # end

  # it 'second intervals' do
  #   expect(desc('5-10 * * * * *')).to eq('Seconds 5 through 10 past the minute')
  # end

  # it 'second minutes hours intervals' do
  #   expect(desc('5-10 30-35 10-12 * * *')).to eq(
  #     'Seconds 5 through 10 past the minute, minutes 30 through 35 past the hour, between 10:00 AM and 12:59 PM')
  # end

  # it 'every 5 minutes at 30 seconds' do
  #   expect(desc('30 */5 * * * *')).to eq('At 30 seconds past the minute, every 5 minutes')
  # end

  # it 'minutes past the hour range' do
  #   expect(desc('0 30 10-13 ? * WED,FRI')).to eq(
  #     'At 30 minutes past the hour, between 10:00 AM and 1:59 PM, only on Wednesday and Friday')
  # end

  # it 'seconds past the minute interval' do
  #   expect(desc('10 0/5 * * * ?')).to eq('At 10 seconds past the minute, every 5 minutes')
  # end

  # it 'between with interval' do
  #   expect(desc('2-59/3 1,9,22 11-26 1-6 ?')).to eq(
  #     'Every 3 minutes, minutes 02 through 59 past the hour, at 1:00 AM, 9:00 AM and 10:00 PM, between day 11 and 26 of the month, January through June')
  # end

  # it 'recurring first of month' do
  #   expect(desc('0 0 6 1/1 * ?')).to eq('At 6:00 AM')
  # end

  # it 'minutes past the hour' do
  #   expect(desc('0 5 0/1 * * ?')).to eq('At 05 minutes past the hour')
  # end

  # it 'every past the hour' do
  #   expect(desc('0 0,5,10,15,20,25,30,35,40,45,50,55 * ? * *')).to eq(
  #     'At 00, 05, 10, 15, 20, 25, 30, 35, 40, 45, 50 and 55 minutes past the hour')
  # end

  # it 'every X minutes past the hour with interval' do
  #   expect(desc('0 0-30/2 17 ? * MON-FRI')).to eq(
  #     'Every 2 minutes, minutes 00 through 30 past the hour, at 5:00 PM, Monday through Friday')
  # end

  # it 'every X days with interval' do
  #   expect(desc('30 7 1-L/2 * *')).to eq('At 7:30 AM, every 2 days, between day 1 and the last day of the month')
  # end

  # it 'one year only with seconds' do
  #   expect(desc('* * * * * * 2013')).to eq('Every second, only in 2013')
  # end

  # it 'one year only without seconds' do
  #   expect(desc('* * * * * 2013')).to eq('Every minute, only in 2013')
  # end

  # it 'two years only' do
  #   expect(desc('* * * * * 2013,2014')).to eq('Every minute, only in 2013 and 2014')
  # end

  # it 'year range 2' do
  #   expect(desc('23 12 * JAN-FEB * 2013-2014')).to eq('At 12:23 PM, January through February, 2013 through 2014')
  # end

  # it 'year range 3' do
  #   expect(desc('23 12 * JAN-MAR * 2013-2015')).to eq('At 12:23 PM, January through March, 2013 through 2015')
  # end

  # context 'multi part range seconds:' do
  #   it 'multi part range seconds 2,4-5' do
  #     expect(desc('2,4-5 1 * * *')).to eq('Minutes 02,04 through 05 past the hour, at 1:00 AM')
  #   end

  #   it 'multi part range seconds 2,26-28' do
  #     expect(desc('2,26-28 18 * * *')).to eq('Minutes 02,26 through 28 past the hour, at 6:00 PM')
  #   end
  # end

  # context 'minutes past the hour:' do
  #   it 'minutes past the hour 5,10, midnight hour' do
  #     expect(desc('5,10 0 * * *')).to eq('At 05 and 10 minutes past the hour, at 12:00 AM')
  #   end

  #   it 'minutes past the hour 5,10' do
  #     expect(desc('5,10 * * * *')).to eq('At 05 and 10 minutes past the hour')
  #   end

  #   it 'minutes past the hour 5,10 day 2' do
  #     expect(desc('5,10 * 2 * *')).to eq('At 05 and 10 minutes past the hour, on day 2 of the month')
  #   end

  #   it 'minutes past the hour 5/10 day 2' do
  #     expect(desc('5/10 * 2 * *')).to eq('Every 10 minutes, starting at 05 minutes past the hour, on day 2 of the month')
  #   end
  # end
end
